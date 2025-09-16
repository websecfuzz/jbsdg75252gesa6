<?php

if (!function_exists('wp_get_current_user')) {
    include(ABSPATH . "wp-includes/pluggable.php");
}

require_once(GOZENFORMS_PATH.'Api/gzapisecret.php');

$curreunt_user = wp_get_current_user();



$formuserid=$curreunt_user->ID;

/**
 * Login status
 * @var int 
 */
$status = 0;

/**
 * Api key
 * @var string 
 */
$apikey = "cnf9df2hffb892f9be98bfh";

/**
 * protocal
 * @var string
 */
$protocal = "http";

/**
 * COookie
 * @var string
 */
$cookie = "";

//check the user server status..
if(isset($_SERVER['HTTPS']) && $_SERVER['HTTPS'] === 'on'){
    $protocal = "https";
}

if(isset($_COOKIE['gz_forms_user_api']) && $_COOKIE['gz_forms_user_api'] != 'adsyiyibib') {
   
    $cookie = sanitize_text_field($_COOKIE['gz_forms_user_api']);
   
}

/**
 * User Domain
 * @var string
 */
$domain = sanitize_text_field($_SERVER['HTTP_HOST']);

/**
 * Host Url
 * @var string
 */
// $host_url = $protocal.'://'.$domain."/";
$host_url = sanitize_text_field(get_site_url());

/**
 * Form Data
 * @var object
 */
$user_query=[];

if($cookie != 'adsyiyibib'){
    $cookie=gzFormapiSecret($cookie,'e');
    $user_query = $wpdb->get_row("SELECT * FROM {$wpdb->prefix}gozen_forms_users WHERE `api_key`= '$cookie'");
    
}

// check the query and get data form query
if(!empty($user_query)){
    $apikey = $user_query->api_key;

    /**
     * user login status
     */
    $login = $user_query->Login_status;
    if($login!= 0){
        $status = 1;
    }
}

if($apikey !== ""){
    // Define GOZENFORMS_SHORTCODE
    define("GOZENFORMS_APIKEY",$apikey);
}


// Define GOZENFORMS_LOGIN_STATUS
define("GOZENFORMS_LOGIN_STATUS",$status);
// Define GOZENFORMS_LOGIN_STATUS
define("GOZENFORMS_CURRENT_USER_ID",$curreunt_user->ID);
define("GOZENFORMS_CURRENT_USER_NICENAME",$curreunt_user->user_nicename);
// Define GOZENFORMS_HOSTURL
define("GOZENFORMS_HOSTURL",$host_url);

?>