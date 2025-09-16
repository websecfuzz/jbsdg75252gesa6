<?php

namespace CleverReach\WordPress\Components\BusinessLogicServices;

use CleverReach\WordPress\Components\Hook_Handler;
use CleverReach\WordPress\Components\InfrastructureServices\Config_Service;
use CleverReach\WordPress\IntegrationCore\BusinessLogic\Interfaces\DisconnectService;
use CleverReach\WordPress\IntegrationCore\Infrastructure\Interfaces\Required\Configuration;
use CleverReach\WordPress\IntegrationCore\Infrastructure\ServiceRegister;

class Disconnect_Service implements DisconnectService {

	private $config_service;

	/**
	 * Removes CleverReach specific data for the user.
	 *
	 * @return void
	 */
	public function disconnect() {
		$hook_handler = new Hook_Handler();
		$hook_handler->cleverreach_disconnect();
		$this->get_config_service()->set_group_connected(false);
	}

	/**
	 * Gets config service
	 *
	 * @return Config_Service
	 */
	private function get_config_service() {
		if ( null === $this->config_service ) {
			$this->config_service = ServiceRegister::getService( Configuration::CLASS_NAME );
		}

		return $this->config_service;
	}
}