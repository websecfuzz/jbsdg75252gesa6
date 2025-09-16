<?php

/**
 * Add gzforms tables in DB.
 */

global $wpdb;

$table_name = $wpdb->prefix.'gozen_forms';
$query = $wpdb->prepare( 'SHOW TABLES LIKE %s', $wpdb->esc_like( $table_name ) );

//check the table is alreably ini DB.
if($wpdb->get_var( $query ) === $table_name){
    return true;

}
else{

    $charset_collate = $wpdb->get_charset_collate();
    $sql = "CREATE TABLE $table_name(
        Id INT(20) NOT NULL AUTO_INCREMENT,
        api_key CHAR(64) NOT NULL,
        form_id CHAR(64) NULL ,
        form_type CHAR(64) NOT NULL DEFAULT 'standard' ,
        width CHAR(64) NOT NULL DEFAULT '80%' ,
        height CHAR(64) NOT NULL DEFAULT '80%',
        size CHAR(64) NOT NULL DEFAULT 'small',
        domain_id CHAR(64) NOT NULL DEFAULT 'fqeD3xpHwfVDWmExBr',
        btn_color CHAR(64) NULL,
        text_color CHAR(64) NULL,
        btn_text CHAR(64) NOT NULL DEFAULT 'Launch',
        slide_dir CHAR(64) NOT NULL DEFAULT 'right',
        shortcode CHAR(200)  NOT NULL DEFAULT 'gozen-forms',
        Login_status INT(20) NOT NULL DEFAULT '0',
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
    $data = "cnf9df2hffb892f9be98bfh";

    $dataApi = gzFormapiSecret($data,"e");

    $wpdb->insert($wpdb->prefix.'gozen_forms',array('api_key' => $dataApi));

}

?>