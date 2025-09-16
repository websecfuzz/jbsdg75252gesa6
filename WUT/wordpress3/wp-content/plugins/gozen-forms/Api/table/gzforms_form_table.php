<?php

/**
 * Add gzforms tables in DB.
 */

global $wpdb;

$table_name = $wpdb->prefix.'gozen_embed_forms';

$query = $wpdb->prepare( 'SHOW TABLES LIKE %s', $wpdb->esc_like( $table_name ) );

//check the table is alreably ini DB.
if($wpdb->get_var( $query ) === $table_name){

    return true;

}
else{
    $charset_collate = $wpdb->get_charset_collate();

    $sql = "CREATE TABLE $table_name(
        Id INT(20) NOT NULL AUTO_INCREMENT,
        form_id CHAR(64) NOT NULL,
        embed_type CHAR(64) NOT NULL,
        shortcode_title CHAR(64) NOT NULL,
        shortcode_tag VARCHAR(600) NOT NULL ,
        active INT(20) NOT NULL DEFAULT '0',
        domainId CHAR(20) NOT NULL ,
        PRIMARY KEY(Id) 
    )$charset_collate;";


    if(!function_exists('dbDelta')){
        require_once(ABSPATH.'wp-admin/includes/upgrade.php');
    }

    require_once(GOZENFORMS_PATH.'Api/gzapisecret.php');

    $wpdb->query( $sql );
    /**
     * default apikey.
     * @var string
     */

}

?>