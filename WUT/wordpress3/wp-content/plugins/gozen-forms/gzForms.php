<?php

/**
 * Plugin Name: GoZen Forms
 * Plugin URI: https://gozen.io/forms/
 * Description: Gozen Forms simplifies the data collection process. Simply select a form template or create one from scratch, modify questions, and share
 * Author: GozenHQ
 * Version: 1.1.5
 * Text Domain:gozenforms
 * Domain Path: /languages/
 * Requires at least :4.6.1
 * Contributors: OptinlyHQ
 * License: GPL v2 or later
 * License URI: http://www.gnu.org/licenses/gpl-2.0.txt
 */


/**
 * Global Variable
 */

global $wpdb;


/**
 * Define Constent variables
 */



defined('GOZENFORMS_VERSION') or define('GOZENFORMS_VERSION','1.1.0');
defined('GOZENFORMS_PATH') or define('GOZENFORMS_PATH',plugin_dir_path(__FILE__));
defined('GOZENFORMS_URL') or define('GOZENFORMS_URL',plugin_dir_URL(__FILE__));


//require path

require_once(GOZENFORMS_PATH.'Api/table/gzforms_form_table.php');
require_once(GOZENFORMS_PATH.'Api/table/gzforms_user_table.php');
// require_once(GOZENFORMS_PATH.'Api/gzforms_table.php');
require_once(GOZENFORMS_PATH.'constvar.php');
require_once(GOZENFORMS_PATH.'Api/gzforms_api.php');
require_once(GOZENFORMS_PATH.'Api/env/env.php');

function gzformhook(){
    require_once(GOZENFORMS_PATH.'uninstall.php');
    deleteGzFormsTable("gozen_embed_forms");
    deleteGzFormsTable("gozen_forms_users");
    // deleteGzFormsTable("gozen_forms");
}

register_deactivation_hook(__FILE__,'gzformhook');

//init plugin
$Gzforms = new GzFormsApi;
$Gzforms->gzinit();

?>
