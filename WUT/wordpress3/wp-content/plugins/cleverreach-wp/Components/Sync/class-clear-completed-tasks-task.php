<?php
/**
 * CleverReach WordPress Integration.
 *
 * @package CleverReach
 */

namespace CleverReach\WordPress\Components\Sync;

use CleverReach\WordPress\IntegrationCore\BusinessLogic\Sync\ClearCompletedTasksTask as BaseClearCompletedTasksTask;
use CleverReach\WordPress\IntegrationCore\BusinessLogic\Sync\RefreshUserInfoTask;
use CleverReach\WordPress\IntegrationCore\Infrastructure\Interfaces\Required\TaskQueueStorage;
use CleverReach\WordPress\IntegrationCore\Infrastructure\ServiceRegister;

/**
 * Class Clear_Completed_Tasks_Task
 *
 * @package CleverReach\WordPress\Components\Sync
 */
class Clear_Completed_Tasks_Task extends BaseClearCompletedTasksTask {

	/**
	 * Removes all completed tasks except Initial_Sync_Task and RefreshUserInfoTask
	 *
	 * @return void
	 */
	public function execute()
	{
		/** @var TaskQueueStorage $taskQueueStorage */
		$taskQueueStorage = ServiceRegister::getService(TaskQueueStorage::CLASS_NAME);
		$deleteLimit = 1000;
		$excludedTypes = array(Initial_Sync_Task::getClassName(), RefreshUserInfoTask::getClassName());

		for ($i = 0; $i < 100; $i++) {
			$deletedCount = $taskQueueStorage->deleteBy($excludedTypes, $this->getFinishedTimestamp(), $deleteLimit);
			if ($deletedCount < $deleteLimit) {
				break;
			}

			$this->reportProgress($i + 1);
			$this->getTimeProvider()->sleep(1);
		}

		$this->reportProgress(100);
	}
}
