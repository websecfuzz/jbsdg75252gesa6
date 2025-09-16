<?php 

/**
 * Uninstall the table when user delete the Gozen forms plugin.
 */

function deleteGzFormsTable($tablename) {

    // if (!defined('WP_UNINSTALL_PLUGIN')) {
    //     die;
    // }

    //Global variable
    global $wpdb;

    $table_name = $wpdb->prefix.$tablename;

    // delete the table.
    $sql = "DROP TABLE IF EXISTS $table_name";

    $wpdb->query($sql);
    delete_option("my_plugin_db_version"); 

}

?>