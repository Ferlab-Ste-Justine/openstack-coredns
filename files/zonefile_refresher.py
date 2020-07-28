#!/usr/bin/env python3
import json, logging, os, socket, time, traceback
from swiftclient.service import SwiftService, SwiftError
#https://sysdig.com/blog/prometheus-metrics/

class SwiftFailureHandler():
    def __init__(self, logger):
        self.consecutive_failures = 0
        self.logger = logger
    
    def reset(self):
        self.consecutive_failures = 0
    
    def handle_failure(self, err):
        host = socket.gethostname()
        self.logger.error(json.dumps({
            "event": "zonefiles_update_error", 
            "host": host, 
            "error": err.value
        }))
        self.consecutive_failures += 1
        #If its not working out, rather than try to recover from potentially obscure connection issues,
        #abort and let systemd restart the process
        if self.consecutive_failures >= 10:
            self.logger.critical(json.dumps({
                "event": "zonefiles_update_abort_process", 
                "host": host
            }))
            exit(1)

class SwiftZonefiles():
    """
    Update zonefiles on disk given the zonefiles in the container
    We assume the process will be running in the directory where the zonefiles will be downloaded.
    We try to be as conservative as possible to ensures retries to update are made on download
    failure or if the process has to restart.
    This involves the following strategy:
    - We always look at the files present on disk to determine what should be deleted.
    - We only overwrite the previous metadata in memory if the download of all updates are successful
    """
    def __init__(self, conn, container, logger):
        self.conn = conn
        self.container = container
        self.logger = logger
        self.objects_metadata = set()
    
    def _list_disk_zonefiles(self):
        return set(os.listdir(os.getcwd()))
    
    def _delete_disk_zonefiles(self, zonefiles):
        if len(zonefiles) > 0:
            for zonefile in zonefiles:
                os.remove(os.path.join(os.getcwd(), zonefile))
            host = socket.gethostname()
            self.logger.info(json.dumps({
                "event": "zonefile_deletions", 
                "files": list(zonefiles),
                "host": host
            }))

    def _update_disk_zonefiles(self, zonefiles):
        success = True
        download_failures = []
        if len(zonefiles) > 0:
            for download_result in self.conn.download(
                container=self.container,
                objects=zonefiles
            ):
                if not download_result['success']:
                    download_failures.append(down_res['object'])
                    success = False
            host = socket.gethostname()
            self.logger.info(json.dumps({
                "event": "zonefile_upserts", 
                "updated_files": list(zonefiles),
                "failed_updates": download_failures,
                "host": host
            }))
        return success

    
    def _get_metadata_adjustments(self):
        updated_objects_metadata = set()
        pages = self.conn.list(container=self.container)
        for page in pages:
            if page["success"]:
                updated_objects_metadata.update(
                    set((item["name"], item["hash"]) for item in page["listing"])
                )
            else:
                raise page["error"]
        downloads = set(map(lambda item: item[0], updated_objects_metadata - self.objects_metadata))
        deletions = self._list_disk_zonefiles() - set(map(lambda item: item[0], updated_objects_metadata))
        return (downloads, deletions, updated_objects_metadata)

    def update(self):
        downloads, deletions, updated_objects_metadata = self._get_metadata_adjustments()
        update_metadata = True
        self._delete_disk_zonefiles(deletions)
        if self._update_disk_zonefiles(downloads):
            self.objects_metadata = updated_objects_metadata

LOGGER = logging.getLogger(__name__)
LOGGER.setLevel(logging.INFO)
CONTAINER = os.environ['ZONEFILES_CONTAINER']
SCRAPE_INTERVAL = int(os.environ.get('SCRAPE_INTERVAL', '3'))
ZONEFILES_PATH = os.environ.get('ZONEFILES_PATH', os.getcwd())

if __name__ == "__main__":
    host = socket.gethostname()
    try:
        os.chdir(ZONEFILES_PATH)
        with SwiftService({}) as swift:
            swift_failure_handler = SwiftFailureHandler(LOGGER)
            swift_zonefiles = SwiftZonefiles(swift, CONTAINER, LOGGER)
            while True:
                try:
                    swift_zonefiles.update()
                    swift_failure_handler.reset()
                except SwiftError as e:
                    swift_failure_handler.handle_failure(e)
                time.sleep(SCRAPE_INTERVAL)
    except Exception as e:
        LOGGER.critical(json.dumps({
            "event": "unexpected_exception",
            "host": host,
            "error": traceback.format_exc()
        }))
        exit(1)