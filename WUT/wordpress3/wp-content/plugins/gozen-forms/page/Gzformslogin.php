<?php

//require gzapisecret file
require_once(GOZENFORMS_PATH.'Api/gzapisecret.php');

/**
 *  
 * Gozen form Login page.
 * 
 */
function gzForms_LoginPage(){

    /**
     * get the form api_key on submit ,and validate the api_key. 
     */

?>

<div id="container">

    <!-- <h1>Gozen <span id="title_content">Froms</span></h1> -->
    
    <h1><img src ="<?php echo GOZENFORMS_URL.'page/images/Logo.png' ?>" style="height:40px"></h1>
    <div id="login_container">
        <h2>Login To Your Account</h2>
        <form method="POST" id="login_form">
            <label>API Access Keys</label>
            <div id="inputcontainer">
                <input type="text" id="api-key" name="api-key"><br>
                <input type="submit" id="submit" name="submit" value="Submit"> 
            </div>
        </form>
        <div id="error-container" hidden></div>
        <div>
            <p style="text-indent:26.5%"><strong>Have an account?</strong> <a style="cursor:pointer;" href="https://app.forms.gozen.io/register" target="_black">Sign up</a></p>
            <p style="text-indent:26.5%">Get your GoZen Forms API key from <a style="cursor:pointer;" href="https://app.forms.gozen.io/settings" target="_black">here</a>.</p>
        </div>
    </div>

</div>

<?php

}


?>