<?php

//require files
require_once(GOZENFORMS_PATH.'page/Gzformslogin.php');
require_once(GOZENFORMS_PATH.'page/templateforms.php');
require_once(GOZENFORMS_PATH.'page/gzform_embedscript.php');

/**
 * init the hook
 */

class GzFormsApi{

    public $login_error = false;

    public function gzinit () {
        add_action('init',array(&$this,'initMenuHook'));
        add_action('init',array(&$this,'gzFormsApiPost'));

    }

    public function gzFormsApiPost(){
        /**
         * Global variable
         */
        global $wpdb;
    
        //after the submit the api key.check the api key validate  or not.

        if(isset($_POST["submit"])){
    
            /**
             * response message
             * @var string
             */
            $message = '';
    
            /**
             * response status 
             * @var int
             */
            $status = 0;
    
            /**
             * response data
             * @var array
             */
            $data = [];
    
            /**
             * Gzforms auth endpoint url
             * @var string
             */
            $url = GOZENFORM_SERVER_API_URL.'/api/v1/wordpress/auth';
    
            /**
             * Response 
             * @var object
             */
            
            $response = [];
    
            //get the api key from post request
            if(isset($_POST["api-key"]) && !empty($_POST["api-key"])){
    
                /**
                 * sanitize the apikey
                 */
                $apikey=sanitize_text_field($_POST["api-key"]);
    
                /**
                 * Bodu content
                 * @var object
                 */
                $body = [
                    'message' => $message,
                    'status' => $status,
                    'data' => $data
                ];
    
                /**
                 * Request Option
                 * @var object
                 */
                $option = [
                    "body" => $body,
                    "headers" => [
                        'content-type' => 'application/json',
                        'api-key'=> $apikey
                    ],
                    'data_format' => 'body'
                ];
    
                /**
                 * if the api_key is not empty,redirect data and check api_key validate or not with WP remote.
                 */
                $response = wp_remote_get($url,$option);
    
                if(is_array($response) && is_wp_error($response)){
                    $this->login_error = true;

                }
    
                else{
    
                    /**
                     * if the apikey validation failed.
                     */
                    $deres =json_decode($response['body'],true);
    
                    if(array_key_exists("error",$deres)){
                        $this->login_error = true;

                    }
                    else{

                        /**
                         * store the apikey if the apikey validate and redirect to templete page.
                         */

                        $check_apikey = gzFormAPikeySave($apikey,GOZENFORMS_CURRENT_USER_NICENAME,GOZENFORMS_CURRENT_USER_ID);
                        setcookie('gz_forms_user_api', $apikey, strtotime('+1 day'));
                        if($check_apikey==true){
                            $wpdb->update($wpdb->prefix.'gozen_forms_users',array("Login_status" => 1),array("Id" => 1));
                            $redir = GOZENFORMS_HOSTURL."/wp-admin/admin.php?page=GzForms&tab=gozenForms";
                            wp_redirect( $redir );
                            exit;
                        }
                    }
                }
            }
            else {
                $this->login_error = true;

            }
    
    
        }
    
    }
    

    //add menu and register endpoints
    public function initMenuHook(){
        add_action('admin_menu',array(&$this,'initMenu'));
        add_action('rest_api_init',array(&$this,'registerFormEndpoint'));
        

    }

    // add style ,script and menu 
    public function initMenu(){

        $gz_forms_icon = 'data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iNDAwIiBoZWlnaHQ9IjQwMCIgdmlld0JveD0iMCAwIDQwMCA0MDAiIGZpbGw9Im5vbmUiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+CjxwYXRoIGQ9Ik0zNzUgMEMyMDUuNTgzIDAgNjYuMjMyNyAxMzAuMzM0IDUxLjQ2NjMgMjk1Ljk2NkM3OS42MTYzIDI1Ni4yNjYgMTE0LjEgMjE4LjA2NiAxNTcuMTUgMTc0LjE1QzE2MC4zNSAxNzAuODUgMTY1LjY1IDE3MC43ODQgMTY4LjkzMyAxNzQuMDM0QzE3Mi4yMTcgMTc3LjI1IDE3Mi4yNjcgMTgyLjUzNCAxNjkuMDUgMTg1LjgxN0MxNjIuNTY2IDE5Mi40MTcgMTU1Ljk4MyAxOTkuMjY3IDE0OS4zNjYgMjA2LjIwMUMxNDUuNTgzIDIxMC4xNTEgMTQxLjg4MyAyMTQuMDg0IDEzOC4yNSAyMTcuOTUxQzEzNy41ODMgMjE4LjY2NyAxMzYuOTE2IDIxOS4zODQgMTM2LjI1IDIyMC4xMTdDODMuMDQ5OSAyNzcuMDg0IDQ1LjAxNjMgMzI2LjY2NiAxNy4zOTkxIDM4OC4yNUMxNS41MTU1IDM5Mi40NSAxNy4zOTkxIDM5Ny4zODQgMjEuNTgyNyAzOTkuMjY2QzIyLjY5OTEgMzk5Ljc2NiAyMy44NDkxIDQwMCAyNC45OTkxIDQwMEMyOC4xODI3IDQwMCAzMS4yMzI3IDM5OC4xNjYgMzIuNjE1NSAzOTUuMDg0QzQyLjQ0OTEgMzczLjE2NyA1My44NjU1IDM1Mi44MzQgNjYuNjk5MSAzMzMuMDVDMTgzLjA5OSAzMzAuMDY2IDI4OS4wNDkgMjY1LjMxNiAzNDQuNTgzIDE2Mi4yODRDMzQ1Ljk2NiAxNTkuNyAzNDUuODk5IDE1Ni41ODQgMzQ0LjM5OSAxNTQuMDVDMzQyLjg4MyAxNTEuNTUgMzQwLjE2NSAxNTAgMzM3LjIzMyAxNTBIMzA2LjM2NkwzNjEuNzE2IDExOC4zNjZDMzYzLjQ2NiAxMTcuMzY2IDM2NC44MTYgMTE1Ljc1IDM2NS40NjYgMTEzLjg1QzM3Ny4zMzMgNzkuMzUgMzgzLjMzMyA0My44NSAzODMuMzMzIDguMzMzNTlDMzgzLjMzMyAzLjczMzU5IDM3OS42IDAgMzc1IDBaIiBmaWxsPSJ3aGl0ZSIvPgo8L3N2Zz4K' ;

        add_menu_page("Gozen Forms","Gozen Forms","manage_options","GzForms",array(&$this,'renderGzformsPage'),$gz_forms_icon);
        wp_register_style('gzforms-style',GOZENFORMS_URL.'css/gzforms.css',array(),GOZENFORMS_VERSION);
        wp_register_script('gzforms-script',GOZENFORMS_URL.'javascript/gzforms.js',array('jquery'),GOZENFORMS_VERSION);
        if( $this -> login_error ) wp_register_script('gzpopup-script',GOZENFORMS_URL.'javascript/gzpopup.js',array('jquery'),GOZENFORMS_VERSION);
    }

    //forms Endpoint url
    public function registerFormEndpoint(){
        register_rest_route('gozen-forms/v1','embedsc',[
            'methods' => "POST",
            'callback' => array($this,'emdedSc'),
            'permission_callback' => '__return_true',
        ]);
        register_rest_route('gozen-forms/v1','logout',[
            'methods' => "POST",
            'callback' => array($this,'dirLogoutFormPage'),
            'permission_callback' => '__return_true',

        ]);
        register_rest_route('gozen-forms/v1','activecode',[
            'methods' => "POST",
            'callback' => array($this,'dirGZActiveForm'),
            'permission_callback' => '__return_true',

        ]);
    }

    //render the template page base login status
    public function renderGzformsPage(){

        global $wpdb;

        /**
         * add the script file and style file in wp.
         */
        wp_enqueue_script('gzforms-script');
        wp_enqueue_script('gzpopup-script');
        wp_enqueue_style('gzforms-style');

        //decrypt the GOZEN_API_KEY if the APi_key is not empty.
        $api = GOZENFORMS_APIKEY?gzFormapiSecret(GOZENFORMS_APIKEY,"d"):" ";
        $active_form = $wpdb->get_results("SELECT form_id FROM {$wpdb->prefix}gozen_embed_forms WHERE `active`= 1");

        $add_nonce = wp_create_nonce("gzforms-plugin-js");
        $ajax_url = admin_url('admin-ajax.php');

        //add the apikey and loginstatus in localize
        $result = [
            'api_key' => $api,
            'status' => GOZENFORMS_LOGIN_STATUS,
            'host_url' => GOZENFORMS_HOSTURL,
            'server_url' =>GOZENFORM_SERVER_URL,
            'server_API' =>GOZENFORM_SERVER_API_URL,
            'active_form' =>$active_form,
        ];

        wp_localize_script('gzforms-script','gzform_url',array('ajax_url'=>$ajax_url,'nonce'=>$add_nonce,'data'=>$result));

        //if the login status falue 
        if(GOZENFORMS_LOGIN_STATUS == "0"){

            gzForms_LoginPage();
        }
        else{
            gzFormTemplateList();
        }
        
    }

    /**
     * Embed Form data form endpoint url
     * @param  $response_data
     * @return $shortcode string
     */

    public function dirGZActiveForm($response_data){
        global $wpdb;
        $headerid = $response_data->get_headers();
        $dataid= $headerid["forms_id"][0];
        $body = $response_data->get_body();
        $body = json_decode($body,true);
        $active =$body['active'];
        $table_name = $wpdb->prefix.'gozen_embed_forms';

        $resdata = $wpdb->query($wpdb->prepare("UPDATE $table_name SET `active`= $active WHERE form_id = '$dataid'"));
        $response = array('success' => true, 'RESPONSE_CODE' => 'PROCESSED', 'data'=> $resdata);

        $status = 200;

        return new \WP_REST_Response($response,$status);

    }
    


    public function emdedSc($response_data){
        global $wpdb;

        /**
         * Form ID
         */
        $headerid = $response_data->get_headers();
        $dataid= $headerid["forms_id"][0];
        $domaind= $headerid["domain_id"][0];

        

        /**
         * Get res body
         */
        $body = $response_data->get_body();
        $body = json_decode($body,true);
        $emabedType = $body['emabed_type'];
    
        /**
         * shortcode
         * @var string
         */
        $sctag = "";

        /**
         * build the shortcode ,based on active form type
         * and form data.
         */
        
       
        $getform = $wpdb->get_results($wpdb->prepare("SELECT * FROM {$wpdb->prefix}gozen_embed_forms WHERE form_id='$dataid' AND embed_type='$emabedType'"));

        $resdata = 0;$rescode="Already EXIST";
            if(empty($getform)){
                $resdata =  $wpdb->insert($wpdb->prefix.'gozen_embed_forms',array(
                    "form_id" => $dataid,
                    "embed_type" => $body['emabed_type'],
                    "shortcode_title" => $body['shortcode_title'],
                    "shortcode_tag" => $body['shortcode_tag'],
                    "active"=>$body['active'],
                    "domainId"=>$domaind,

                ));
                $rescode = "PROCESSED";
            }else{
                $resdata = $wpdb->update($wpdb->prefix.'gozen_embed_forms',array('shortcode_tag' => $body['shortcode_tag'],"active"=>$body['active']),array("form_id" => $dataid,"shortcode_title"=>$body['shortcode_title']));
                $rescode="UPdATE form";
            }

                $response = array('success' => true, 'RESPONSE_CODE' => $rescode, 'data'=> $resdata);

                $status = 200;
        
                return new \WP_REST_Response($response,$status);

    }

        /**
     * Endpoint callback function for dirto_Logout,it update the login status
     * @return mixed
     */
    public function dirLogoutFormPage($response_data){

        global $wpdb;

        $headerid = $response_data->get_headers();
        $dataid= $headerid["api_key"][0];
        $dataid=gzFormapiSecret($dataid,'e');
        
        $data = $wpdb->update($wpdb->prefix.'gozen_forms_users',array('Login_status'=>0),array("api_key"=>$dataid));

        $response = array('success' => true, 'RESPONSE_CODE' => 'PROCESSED','data'=>$data);
        $status = 200;
    
        return new \WP_REST_Response($response,$status);
    }
}

?>
