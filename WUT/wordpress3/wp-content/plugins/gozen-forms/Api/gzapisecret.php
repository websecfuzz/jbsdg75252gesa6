<?php

/**
 * encrypt or decrypt the string value.
 * @param $string
 * @param $encrypt default value-'e' 
 * @return string
 */

function gzFormapiSecret($string, $encrypt = "e"){

    global $wpdb;

    $key = "XJkvSrCTgu";
    $secret_iv = 1204192494329980;
    $ciphering = "AES-128-CTR";
    $options = 0;

    // "e"-encrypt 
    if($encrypt == "e"){
        $data = openssl_encrypt($string,$ciphering,$key,$options,$secret_iv);
    }
     //decrypt
    else{
        $data = openssl_decrypt($string,$ciphering,$key,$options,$secret_iv);
    }
    return $data;
}

/**
 * store the apikey in DB.
 * @param apikey
 * @return boolean
 */
function gzFormAPikeySave($api,$username,$userID){ 

    global $wpdb;

    $status = false;

    $data = gzFormapiSecret($api,"e");

    $get_per_api_key = $wpdb->get_row($wpdb->prepare("SELECT api_key FROM {$wpdb->prefix}gozen_forms_users WHERE `api_key`=%s",$data));

    
    if(!empty($get_per_api_key)){
        $wpdb->update($wpdb->prefix.'gozen_forms_users',array('Login_status' => 1),array("api_key" => $data));
        return true;
    } 
    else {
        $wpdb->insert($wpdb->prefix.'gozen_forms_users',array('api_key' => $data,'Login_status'=> 1,"login_user_id"=>$userID,"login_user_name"=>$username));
        return true;
    }

}

?>