<?php

/**
 * the login status is true this page will be active
 * and Display the user form data.
 */
function gzFormTemplateList(){


?>
<div id="formContainer">

    <div id="header">
    <!-- Gozen <span id="title_content">Froms</span> -->
        <h1><img src ="<?php echo GOZENFORMS_URL.'page/images/Logo.png' ?>" style="height:40px"></h1>
        <div id="navigator">
            <!-- <P>Forms</p> -->
            <p><a id="docs" href ="https://docs.gozen.io/zenforms-knowledge-base/" target="_black">Docs</a></p>
            <div id="user-profile" data-active="deactive">
                <img id="userimg-top-val" src="">
                <!-- <p id="username-top-val"></P> -->
                <div id="popup-menu" data-active="false" hidden>
                    <p id="userbio"><span id="username">Viswa</span><span id="useremail">Viswa@gozen.io</span></p>
                    <p id="userplan">plan:<span id="currentplan">free</span></p>
                    <p id="logout"><svg stroke="currentColor" fill="currentColor" stroke-width="0" viewBox="0 0 24 24" class="w-4 h-4 text-black" height="1em" width="1em" xmlns="http://www.w3.org/2000/svg"><path fill="none" d="M0 0h24v24H0z"></path><path d="M17 7l-1.41 1.41L18.17 11H8v2h10.17l-2.58 2.58L17 17l5-5zM4 5h8V3H4c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h8v-2H4V5z"></path></svg><span>Logout</span></p>
                </div>
            </div>

        </div>
    </div>
    <!-- <div id="user-info">
        <h2>My Account:</h2>
        <div id="info">
            <p id="useremail">Email: <span id="useremail-val"></span></p>
            <p id="username">Username: <span id="username-val"></span></p>
            <p id="planinfo">Plan: <span id="planinfo-val"></span></p>
        </div>
    </div> -->
    <div id="gzformbody">
        <div id="formworkspace">
            <h3>My Workspace</h3>
            <hr/>
            <div id="workspacelist">
            </div>
        </div>
        <div id="formembedlist">
            <div id="formsearch">
                <div id="searchbar">
                    <span>
                        <svg width="20" height="20" viewBox="0 0 20 20" fill="none" xmlns="http://www.w3.org/2000/svg">
                            <path d="M9.6247 17.3105C5.3872 17.3105 1.93719 13.8605 1.93719 9.62305C1.93719 5.38555 5.3872 1.93555 9.6247 1.93555C13.8622 1.93555 17.3122 5.38555 17.3122 9.62305C17.3122 13.8605 13.8622 17.3105 9.6247 17.3105ZM9.6247 3.06055C6.0022 3.06055 3.06219 6.00805 3.06219 9.62305C3.06219 13.238 6.0022 16.1855 9.6247 16.1855C13.2472 16.1855 16.1872 13.238 16.1872 9.62305C16.1872 6.00805 13.2472 3.06055 9.6247 3.06055Z" fill="#586474"/>
                            <path d="M17.5001 18.0606C17.3576 18.0606 17.2151 18.0081 17.1026 17.8956L15.6026 16.3956C15.3851 16.1781 15.3851 15.8181 15.6026 15.6006C15.8201 15.3831 16.1801 15.3831 16.3976 15.6006L17.8976 17.1006C18.1151 17.3181 18.1151 17.6781 17.8976 17.8956C17.7851 18.0081 17.6426 18.0606 17.5001 18.0606Z" fill="#586474"/>
                        </svg>
                    </span>
                    <input type="text" name="search" id="gzformsearch" placeholder="Search" >
                </div>
                <div id="gzcreatenewfrom">
                    <a href="<?php echo GOZENFORM_SERVER_URL."/workspace" ?>" target="_black">
                        <span style="margin:auto 4px;margin-top:13px;">
                            <svg width="18" height="18" viewBox="0 0 18 18" fill="none" xmlns="http://www.w3.org/2000/svg">
                            <g clip-path="url(#clip0_85_39)">
                            <path d="M13.4999 9.75H9.74994V13.5C9.74994 13.9125 9.41244 14.25 8.99994 14.25C8.58744 14.25 8.24994 13.9125 8.24994 13.5V9.75H4.49994C4.08744 9.75 3.74994 9.4125 3.74994 9C3.74994 8.5875 4.08744 8.25 4.49994 8.25H8.24994V4.5C8.24994 4.0875 8.58744 3.75 8.99994 3.75C9.41244 3.75 9.74994 4.0875 9.74994 4.5V8.25H13.4999C13.9124 8.25 14.2499 8.5875 14.2499 9C14.2499 9.4125 13.9124 9.75 13.4999 9.75Z" fill="white"/>
                            </g>
                            <defs>
                            <clipPath id="clip0_85_39">
                            <rect width="18" height="18" fill="white"/>
                            </clipPath>
                            </defs>
                            </svg>

                        </span>
                        <span style="margin:auto;font-size:14px;">Create New Form<span>
                    </a>
                </div>
            </div>
            <div id="gzlistedforms">

            </div>
            
            
        </div>
    </div>

</div>

<?php
}

?>