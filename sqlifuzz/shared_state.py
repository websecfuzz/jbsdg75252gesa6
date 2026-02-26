# Shared state module to avoid circular imports
import time

# Activity tracking for idle shutdown monitor
last_activity_time = time.time()
