<?php

namespace CleverReach\WordPress\database\migrations;

use CleverReach\WordPress\Components\Utility\Update\Update_Schema;
use CleverReach\WordPress\IntegrationCore\BusinessLogic\Interfaces\Proxy;
use CleverReach\WordPress\IntegrationCore\BusinessLogic\Sync\RegisterEventHandlerTask;
use CleverReach\WordPress\IntegrationCore\Infrastructure\Logger\Logger;
use CleverReach\WordPress\IntegrationCore\Infrastructure\ServiceRegister;
use Exception;

class Migration_1_5_17 extends Update_Schema {

	/**
	 * @inheritDoc
	 */
	public function update() {
		if ( $this->config_service->getAccessToken() && $this->config_service->getRefreshToken() ) {
			try {
				$this->register_group_deleted_webhook();
			} catch ( Exception $exception ) {
				Logger::logError( 'Error while registering to group deleted webhook. Reason: ' . $exception->getMessage() );
			}
		}
	}

	/**
	 * Register group deleted webhook
	 *
	 * @return void
	 */
	private function register_group_deleted_webhook() {
		$proxy           = ServiceRegister::getService( Proxy::CLASS_NAME );
		$eventHookParams = array(
			'url'    => $this->config_service->getCrEventHandlerURL(),
			'event'  => RegisterEventHandlerTask::GROUP_DELETED_EVENT,
			'verify' => $this->config_service->getCrEventHandlerVerificationToken(),
		);

		if ( stripos( $eventHookParams[ 'url' ], 'https://' ) === 0 ) {
			$callToken = $proxy->registerEventHandler( $eventHookParams );
			$this->config_service->setCrGroupDeletedEventHandlerCallToken( $callToken );
		} else {
			Logger::logWarning( 'Cannot register CleverReach event hook for non-HTTPS domains.' );
		}
	}
}