<?php
/**
 * CleverReach WordPress Integration.
 *
 * @package CleverReach
 */

namespace CleverReach\WordPress\Database\Migrations;

use CleverReach\WordPress\Components\Sync\Clear_Completed_Tasks_Task;
use CleverReach\WordPress\Components\Utility\Update\Update_Schema;
use CleverReach\WordPress\IntegrationCore\BusinessLogic\RepositoryRegistry;
use CleverReach\WordPress\IntegrationCore\BusinessLogic\Scheduler\Models\DailySchedule;
use CleverReach\WordPress\IntegrationCore\Infrastructure\ORM\Exceptions\RepositoryClassException;
use CleverReach\WordPress\IntegrationCore\Infrastructure\ORM\Exceptions\RepositoryNotRegisteredException;

/**
 * Class Migration_1_5_19
 *
 * @package CleverReach\WordPress\Database\Migrations
 */
class Migration_1_5_19 extends Update_Schema {

	/**
	 * @return void
	 * @throws RepositoryClassException
	 * @throws RepositoryNotRegisteredException
	 */
	public function update() {
		$schedule_repository = RepositoryRegistry::getScheduleRepository();

		$clear_completed_tasks_schedule = new DailySchedule(
			new Clear_Completed_Tasks_Task(),
			$this->config_service->getQueueName()
		);

		$clear_completed_tasks_schedule->setMinute( 1 );
		$clear_completed_tasks_schedule->setNextSchedule();
		$schedule_repository->save( $clear_completed_tasks_schedule );
	}
}
