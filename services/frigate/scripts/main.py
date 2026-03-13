import logging
import os
import socket
from contextlib import closing
from datetime import datetime, timedelta
from pathlib import Path

import boto3
import pytz
import requests
from apscheduler.schedulers.blocking import BlockingScheduler
from boto3.s3.transfer import TransferConfig
from tenacity import retry, stop_after_attempt, wait_exponential

# Configuration from environment variables
FRIGATE_HOST = "http://frigate:5000"
S3_BUCKET = os.getenv("S3_BUCKET")
AWS_ACCESS_KEY_ID = os.getenv("AWS_ACCESS_KEY_ID")
AWS_SECRET_ACCESS_KEY = os.getenv("AWS_SECRET_ACCESS_KEY")
AWS_REGION = os.getenv("AWS_REGION", "ap-south-1")
CAMERAS = os.getenv("CAMERAS", "roadside,stairs").split(",")
LOG_DIR = "/app/logs"

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s | %(name)s | %(levelname)s | %(funcName)s:%(lineno)d | %(message)s',
    handlers=[
        logging.FileHandler(f"{LOG_DIR}/s3_export.log"),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger('FRIGATE_EXPORT')

# Global clients to prevent memory leaks
s3_client = None
session = requests.Session()


def check_internet_connection():
    """Check if internet connection is available"""
    try:
        with closing(socket.create_connection(("s3.amazonaws.com", 443), timeout=5)) as sock:
            return True
    except (socket.error, socket.timeout):
        return False


def get_s3_path(video_path):
    """Convert video path to organized S3 path"""
    filename = "unknown"  # Initialize with default value
    try:
        filename = os.path.basename(video_path)

        # Expected format: camera_YYYYMMDD_HHMMSS-YYYYMMDD_HHMMSS_randomid.mp4
        # Example: roadside_20251011_160000-20251011_170000_6t96gi.mp4

        if '_' not in filename or '-' not in filename:
            logger.error(f"Invalid filename format (missing _ or -): {filename}")
            return None

        # Split by underscore and dash
        parts = filename.split('_')
        if len(parts) < 3:
            logger.error(f"Invalid filename format (insufficient parts): {filename}")
            return None

        camera = parts[0]
        date_str = parts[1]
        time_part = parts[2].split('-')[0]  # Get start time before the dash

        # Validate date and time format
        if len(date_str) != 8 or len(time_part) != 6:
            logger.error(f"Invalid date/time format in filename: {filename}")
            return None

        year = date_str[:4]
        month = date_str[4:6]
        day = date_str[6:8]
        hour = time_part[:2]
        minute = time_part[2:4]

        # Validate extracted values
        if not (year.isdigit() and month.isdigit() and day.isdigit() and
                hour.isdigit() and minute.isdigit()):
            logger.error(f"Non-numeric date/time values in filename: {filename}")
            return None

        return f"{camera}/{year}/{month}/{day}/{hour}/{minute}M.mp4"

    except Exception as e:
        logger.error(f"Unexpected error parsing filename '{filename}' from path '{video_path}': {e}")
        return None


@retry(stop=stop_after_attempt(3), wait=wait_exponential(multiplier=1, min=4, max=10))
def upload_to_s3(local_file_path, s3_key):
    """Upload file to S3 with Glacier Instant Retrieval and retry logic"""
    global s3_client
    
    if s3_client is None:
        s3_client = boto3.client(
            's3',
            aws_access_key_id=AWS_ACCESS_KEY_ID,
            aws_secret_access_key=AWS_SECRET_ACCESS_KEY,
            region_name=AWS_REGION
        )
    
    config = TransferConfig(
        multipart_threshold=100 * 1024 * 1024,  # 100MB
        multipart_chunksize=100 * 1024 * 1024,  # 100MB
        use_threads=True,
        max_concurrency=2,
    )

    try:
        # Upload file with Glacier Instant Retrieval storage class
        s3_client.upload_file(
            local_file_path,
            S3_BUCKET,
            s3_key,
            ExtraArgs={
                'StorageClass': 'GLACIER_IR'
            },
            Config=config
        )

        # Verify upload
        s3_client.head_object(Bucket=S3_BUCKET, Key=s3_key)
        logger.info(f"Successfully uploaded and verified {s3_key}")
        return True

    except Exception as e:
        logger.error(f"Failed to upload {s3_key}: {e}")
        raise


@retry(stop=stop_after_attempt(3), wait=wait_exponential(multiplier=1, min=10, max=10))
def get_all_exports():
    """Get all exports from Frigate"""
    response = session.get(f"{FRIGATE_HOST}/api/exports", timeout=30)
    response.raise_for_status()
    return response.json()


def get_finished_exports():
    """Get list of finished exports from Frigate"""
    exports = get_all_exports()
    return [exp for exp in exports if not exp.get('in_progress')]


@retry(stop=stop_after_attempt(3), wait=wait_exponential(multiplier=1, min=10, max=10))
def delete_export(event_id):
    """Delete export from Frigate"""
    response = session.delete(f"{FRIGATE_HOST}/api/export/{event_id}", timeout=30)
    response.raise_for_status()
    logger.info(f"Successfully deleted export {event_id}")
    return True


def get_past_ten_minute_window():
    """Get epoch times for the past 10 minutes with 2-minute delay"""
    try:
        ist = pytz.timezone('Asia/Kolkata')
        current_time = datetime.now(ist) - timedelta(minutes=12)

        # Round down to nearest 10-minute boundary
        minute = current_time.minute
        rounded_minute = (minute // 10) * 10

        start_time = current_time.replace(minute=rounded_minute, second=0, microsecond=0)
        end_time = start_time + timedelta(minutes=10)

        start_time_epoch = int(start_time.timestamp())
        end_time_epoch = int(end_time.timestamp())

        return start_time_epoch, end_time_epoch
    except Exception as e:
        logger.error(f"Error getting past 10-minute details: {e}")
        raise


@retry(stop=stop_after_attempt(3), wait=wait_exponential(multiplier=1, min=10, max=10))
def export_video(camera, start_time_epoch, end_time_epoch):
    """Export video for specific camera and time range"""
    url = f"{FRIGATE_HOST}/api/export/{camera}/start/{start_time_epoch}/end/{end_time_epoch}"

    payload = {
        "playbook": "realtime",
        "source": "recordings"
    }

    headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json'
    }

    response = session.post(
        url=url,
        json=payload,
        headers=headers,
        timeout=30
    )
    response.raise_for_status()
    logger.info(f"Export requested for {camera}: {response.text}")


def upload_and_cleanup():
    """Process all finished exports"""
    try:
        # Check internet connection before processing
        if not check_internet_connection():
            logger.warning("No internet connection detected. Skipping upload cycle.")
            return
            
        finished_exports = get_finished_exports()
        logger.info(f"Found {len(finished_exports)} finished exports")

        for export in finished_exports:
            event_id = export.get('id')
            file_path = export.get('video_path')
            filename = Path(file_path).name
            local_file_path = f"/media/frigate/exports/{filename}"

            # Check if file exists
            if not Path(local_file_path).exists():
                logger.error(f"Export file not found: {local_file_path}")
                continue

            s3_key = get_s3_path(local_file_path)
            if s3_key is None:
                logger.error(f"Failed to parse filename for export {event_id}: {filename}. Skipping upload.")
                continue

            logger.info(f"Processing export {event_id}: {s3_key}")

            try:
                upload_to_s3(local_file_path, s3_key)
                delete_export(event_id)
                logger.info(f"Successfully processed and cleaned up export {event_id}")
            except Exception as e:
                logger.error(f"Failed to process export {event_id}: {e}")

    except Exception as e:
        logger.error(f"Error processing exports: {e}")


def handle_stuck_exports():
    """Handle exports stuck in progress for 30+ minutes"""
    try:
        exports = get_all_exports()
        current_time = datetime.now()
        stuck_exports = []
        
        for export in exports:
            if not export.get('in_progress'):
                continue
                
            # Use the date field (epoch timestamp) from API response
            export_date = datetime.fromtimestamp(export.get('date', 0))
            
            if (current_time - export_date).total_seconds() > 1800:  # 30 minutes
                stuck_exports.append(export)
        
        if not stuck_exports:
            return
            
        logger.info(f"Found {len(stuck_exports)} stuck exports (30+ minutes old)")
        
        for export in stuck_exports:
            try:
                event_id = export.get('id')
                camera = export.get('camera')
                filename = os.path.basename(export.get('video_path', ''))
                
                # Extract time range from filename: camera_YYYYMMDD_HHMMSS-YYYYMMDD_HHMMSS_id.mp4
                parts = filename.split('_')
                if len(parts) >= 4:
                    start_date = parts[1]  # 20251013
                    start_time = parts[2].split('-')[0]  # 075000
                    end_date = parts[2].split('-')[1]  # 20251013
                    end_time = parts[3]  # 080000
                    
                    start_datetime = datetime.strptime(start_date + start_time, '%Y%m%d%H%M%S')
                    end_datetime = datetime.strptime(end_date + end_time, '%Y%m%d%H%M%S')
                    
                    start_epoch = int(start_datetime.timestamp())
                    end_epoch = int(end_datetime.timestamp())
                        
                    # Re-submit export request first
                    export_video(camera, start_epoch, end_epoch)
                    logger.info(f"Re-submitted export for {camera}: {start_epoch} to {end_epoch}")

                    # Only delete if re-submission was successful
                    delete_export(event_id)
                    logger.info(f"Deleted stuck export {event_id}")

            except Exception as e:
                logger.error(f"Failed to handle stuck export {export.get('id')}: {e}")
                
    except Exception as e:
        logger.error(f"Error handling stuck exports: {e}")


def export():
    """Main export function"""
    try:
        # Get past 10-minute time range
        start_time_epoch, end_time_epoch = get_past_ten_minute_window()
        logger.info(f"Exporting past 10 minute videos: {start_time_epoch} to {end_time_epoch}")

        # Create exports for all cameras
        for camera in CAMERAS:
            try:
                export_video(camera.strip(), start_time_epoch, end_time_epoch)
                logger.info(f"Exporting for {camera}")
            except Exception as e:
                logger.error(f"Failed to export for {camera}: {e}")

    except Exception as e:
        logger.error(f"Error in export: {e}")


def main():
    """Main function with APScheduler"""
    logger.info("Frigate Video Export Service starting...")
    logger.info(f"Configured cameras: {CAMERAS}")
    logger.info(f"S3 Bucket: {S3_BUCKET}")
    logger.info(f"AWS Region: {AWS_REGION}")

    # Validate environment variables
    if not AWS_ACCESS_KEY_ID or not AWS_SECRET_ACCESS_KEY:
        logger.error("AWS credentials not found in environment variables")
        return

    scheduler = BlockingScheduler()

    # Export job - run every 12 minutes at 2nd, 12th, 22nd, 32nd, 42nd, 52nd minute
    scheduler.add_job(export, 'cron', minute='2,12,22,32,42,52', second=0)

    # Upload job - run every 5 minutes
    scheduler.add_job(upload_and_cleanup, 'cron', minute='*/5', second=0, max_instances=1)

    # Stuck exports cleanup - run every 30 minutes
    scheduler.add_job(handle_stuck_exports, 'cron', minute='*/30', second=0, max_instances=1)

    logger.info("Scheduler started - Export: every 12 minutes, Upload: every 5 minutes, Stuck cleanup: every 30 minutes")
    try:
        scheduler.start()
    except KeyboardInterrupt:
        logger.info("Scheduler stopped")
    finally:
        session.close()


if __name__ == "__main__":
    main()
    