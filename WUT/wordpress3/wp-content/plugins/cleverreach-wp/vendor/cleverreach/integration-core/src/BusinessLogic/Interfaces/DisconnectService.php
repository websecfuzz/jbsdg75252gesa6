<?php

namespace CleverReach\WordPress\IntegrationCore\BusinessLogic\Interfaces;

interface DisconnectService
{
    const CLASS_NAME = __CLASS__;

    /**
     * Removes CleverReach specific data for the user.
     */
    public function disconnect();
}