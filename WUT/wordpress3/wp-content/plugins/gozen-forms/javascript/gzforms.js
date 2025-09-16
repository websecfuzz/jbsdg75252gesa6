(function($){
  $(document).ready( ()=>{

      function logout(){
          $.ajax({
              url:`${host}/wp-json/gozen-forms/v1/logout`,
              type:"POST",
              headers:{
                  "content-type":"application//json",
                  'api-key':apikey,
              },
              success: (res) => {

                  location.href = `${host}/wp-admin/admin.php?page=GzForms`
              },
              error: (err) => {
                  alert("something Wrong!");
              }

          })
      }

      let apikey = gzform_url.data.api_key,
          status = gzform_url.data.status,
          host = gzform_url.data.host_url,
          serverurl = gzform_url.data.server_url,
          apiurl = gzform_url.data.server_API,
          activeform = gzform_url.data.active_form;
          // console.log(activeform);





      if(status == 1){
          $.ajax({
              url: `${apiurl}/api/v1/wordpress/auth?`,
              type:"GET",
              headers:{
                  "constent-type":"application/json",
                  "api-key":apikey
              },
              success: (res) => {

                  // get user info and worksapce details.
                  let user = res.user,
                      domains=res.domains,
                      workspace = res.workspaces;



                  //get tag;
                  let formtable = document.getElementById("gzlistedforms"),
                      username = document.querySelector("#username"),
                      useremail = document.querySelector("#useremail")
                      userplan = document.querySelector("#currentplan")
                      userimg = document.querySelector("#userimg-top-val");
                      // username_top = document.getElementById("username-top-val");


                  userimg.src = user.profilePictureUrl;
                  username.innerText = user.name;
                  useremail.innerText = user.email;
                  userplan.innerText = user.plan;

                  let count = 1;
                  let seccount=1;

                  let checkdomainstatus = domains.find( (domains) => {if(domains.domain == window.location.hostname) return status = domains.id }  );
                  let currentdomain = (checkdomainstatus == undefined)?"":checkdomainstatus;



                  function setparam(arrparam, mode ,formID) {
                      let content;
                      if(mode == 'popupsize'){
                          content = `
                          <div class="gzfparamiconoption" id="gzfiop${mode}${formID}">
                              <span class="gzfparamiconoptionlist" data-id="${formID}" data-param="${mode}" >${arrparam[0]}</span>
                              <span class="gzfparamiconoptionlist" data-id="${formID}" data-param="${mode}" >${arrparam[1]}</span>
                              <span class="gzfparamiconoptionlist" data-id="${formID}" data-param="${mode}" >${arrparam[2]}</span>

                              </div>
                          `
                      }
                      if(mode == 'sliderdir'){
                           content = `
                          <div class="gzfparamiconoption" id="gzfiop${mode}${formID}">
                              <span class="gzfparamiconoptionlist" data-id="${formID}" data-param="${mode}" >${arrparam[0]}</span>
                              <span class="gzfparamiconoptionlist" data-id="${formID}" data-param="${mode}" >${arrparam[1]}</span>
                          </div>

                          `
                      }
                      else{
                           content = `
                          <div class="gzfparamiconoption" id="gzfiop${mode}${formID}">

                              <span class="gzfparamiconoptionlist" data-id="${formID}" data-param="${mode}" >${arrparam[0]}</span>
                              <span class="gzfparamiconoptionlist" data-id="${formID}" data-param="${mode}" >${arrparam[1]}</span>
                              <span class="gzfparamiconoptionlist" data-id="${formID}" data-param="${mode}" >${arrparam[2]}</span>

                              </div>
                          `
                      }
                  return content;
                  }

                  if(currentdomain == '' || Object.keys(domains).length == 0){
                      let adderrcontent = `
                      <div>
                          <h3 class="errorcontain" >Add Your Domain</h3>
                          <h4 class="errorcontain">Your Current Domain Not match with your GoZen Forms Domain's </h4>
                          <hr style="display:flex;margin: 4px auto;width:30%;" >
                          <div class="errorcontaincheck">
                              <h3>Check Your Domain:</h3>
                              <div><span class="list">1</span> <p>Open Your GoZen Form App and Click User Profile.</p></div>
                              <div><span class="list">2</span> <p>And <span class="Highlight">Settings > Domain</span> Click <span class="Highlight">"Add Domain"</span> and your Domain.<br/>you can find  <a href="${serverurl}/settings" target="_black">here</a></p></div>
                              <div><span class="list">3</span> <p>Copy & Paste Your Current Domain <span class="Highlight">" ${window.location.href} "</span></p></div>
                          <div>
                      </div>
                      `
                      formtable.innerHTML += adderrcontent;
                  }
                  else if(Object.keys(workspace).length == 0){
                      let adderrcontent = `
                      <div>
                          <h3 class="errorcontain" >Add Your Forms</h3>
                          <h4 class="errorcontain">No forms were found. create New form <a href="${serverurl}/workspace" target="_black">here</a> <h4>
                      </div>

                      `
                      formtable.innerHTML += adderrcontent;
                  }

                  else{



                      //set form data value in formtable dashboard
                      for(const prop in workspace){
                          let currentworkspace = '';
                          let Activecode = "1";
                           seccount==Activecode? currentworkspace = prop :"";

                          let setwordpress =`<p class="gzfwsi"  data-id="${prop}" ${seccount==Activecode?"style='background:#F1F5FE;color:#2563EB;'":""} >${workspace[prop].name}<span>${Object.keys(workspace[prop].forms).length}</span></p>`
                          let getworkspacelist = document.getElementById('workspacelist');
                          getworkspacelist.innerHTML += setwordpress;
                          if (seccount == Activecode) currentfoemlist(prop)

                          $('.gzfwsi').each(function(){
                              $(this).click(function(){
                                  let wsIDs = $(this).attr('data-id');

                                  $('.gzfwsi').each(function(){
                                      if($(this).attr('data-id') == wsIDs){ $(this).css({'background':"#F1F5FE","color":"#2563EB"}) ; currentfoemlist(wsIDs) }
                                      else $(this).css({'background':"white","color":"black"})
                                  })
                              })
                          })

                          seccount++;



                          function currentfoemlist(wsID){

                              formtable.setAttribute('data-activeworkspace',wsID)

                              createform(workspace[wsID].forms)

                              function createform(formarr){

                                  formtable.innerHTML = '';

                                  formarr.forEach( (list,index) => {

                                      let activeformstatus = activeform.find(function(form){
                                          if(form.form_id == list.formId) return form;
                                      })


                                      let activemode = '1';
                                      let activees = true;
                                      let formimgsrc = "";
                                      let btnstatus = (list.live == true)? "":"disabled";

                                      if(!list.style.background == ""){
                                          formimgsrc = list.style.background.split("|");

                                      }

                                      let addtabledata = `
                                      <div class="gzformslistcont" >
                                      <div class="gzembedformslist" >
                                          <div class="gzformsimg"style="background:${formimgsrc != ""? formimgsrc[0] == "image"?`url('${formimgsrc[1]}')`:formimgsrc[1] :""};background-size:75px 75px;">

                                          </div>
                                          <div class="gzformslisttitle">
                                              <h4>${list.name}</h4>
                                              <span></span>
                                          </div>
                                          <div class="gzembedformslistsec2" >
                                              <p class="Gzformslivestaus"><span style="${(list.live == true)? "background:#49D57A;border:none;":"background:#DC2626;border:none;"}"></span>${(list.live == true)? "Published":"Paused   "}</p>
                                              <div class="Gzformsactivebut" >
                                                  <div class="Gzformsactivebutcon" id="gzfab${list.formId}" data-id="${list.formId}" data-active="${(activeformstatus?.form_id == list.formId)?"active":"deactive"}" style=${(activeformstatus?.form_id == list.formId)?"background:#2563EB;":""} >
                                                      <div class="Gzformsactiveswitch" id="gzfas${list.formId}"style=${(activeformstatus?.form_id == list.formId)?"margin-left:24px;":""} ></div>
                                                  </div>
                                              </div>
                                              <button class="gzformsgetcode" id="${list.formId}" data-count="${index}" ${btnstatus} ${ !list.live ? "style='background:#E0E0E0'":""} >Get the Code</button>
                                              <div style="display:flex;width:30px;margin:auto 0.75rem;cursor: pointer;">
                                                  <div class="gzfomsediteroptionicon" data-id="${list.formId}">
                                                      <svg width="24" height="24" margin="auto 0.75rem" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                                                          <path d="M12 14C13.1046 14 14 13.1046 14 12C14 10.8954 13.1046 10 12 10C10.8954 10 10 10.8954 10 12C10 13.1046 10.8954 14 12 14Z" fill="#06152D"/>
                                                          <path d="M12 7C13.1046 7 14 6.10457 14 5C14 3.89543 13.1046 3 12 3C10.8954 3 10 3.89543 10 5C10 6.10457 10.8954 7 12 7Z" fill="#06152D"/>
                                                          <path d="M12 21C13.1046 21 14 20.1046 14 19C14 17.8954 13.1046 17 12 17C10.8954 17 10 17.8954 10 19C10 20.1046 10.8954 21 12 21Z" fill="#06152D"/>
                                                      </svg>
                                                  </div>
                                              </div>
                                              <div class="gzfomsediteroption" id="gzfeo${list.formId}" style="postion:absolute" ><p class="gzfeop" id="gzfeop${list.formId}" data-id="${list.formId}"><a href="${serverurl}/editor/${list.formId}" target="_black">Edit Form</a></p></div>
                                          </div>
                                      </div>
                                      <div class="gzformsediter" id="gzfe${list.formId}" >
                                          <div class="gzformspreview">
                                              <div class="gzformspreviewcontent" >
                                              </div>
                                          </div>
                                          <div class="gzformsembedediter">
                                              <div class="gzformsembedmode" id="gzfem${list.formId}" data-active-mode="standard">
                                                  <h3>Embed Mode</h3>
                                                  <div>
                                                      <p class="gzformsembedmodecontent" data-index="1" data-id="${list.formId}" style="margin-left:0px;">
                                                          <span class="gzformsembedmodeicon">
                                                          <svg width="106" height="74" viewBox="0 0 106 74" fill="none" xmlns="http://www.w3.org/2000/svg">
                                                          <rect x="0.5" y="0.5" width="105" height="73" rx="5.5" fill="white" stroke="${ (activemode == '1') ? "#3D5AF1" : "#E0E0E0"}" id="standard-stroke-${list.formId}" />
                                                          <rect x="8" y="8" width="90" height="58" rx="4" fill="${ (activemode == '1') ? "#3D5AF1" : "#E0E0E0"}" id="standard-rect-${list.formId}"/>
                                                          </svg>
                                                          </span>
                                                          <span class="gzformsembedmodetype" style ="${ (activemode == '1') ? "color:#3D5AF1;" : "color:#E0E0E0;"}"id="standard-p-${list.formId}" >Standard</span>
                                                      <p>
                                                      <p class="gzformsembedmodecontent" data-index="2" data-id="${list.formId}">
                                                          <span class="gzformsembedmodeicon">
                                                          <svg width="106" height="74" viewBox="0 0 106 74" fill="none" xmlns="http://www.w3.org/2000/svg">
                                                          <rect x="0.5" y="0.5" width="105" height="73" rx="5.5" fill="white" stroke="${ (activemode == '2') ? "#3D5AF1" : "#E0E0E0"}" id="popup-stroke-${list.formId}"/>
                                                          <rect x="16" y="15" width="74" height="44" rx="4" fill="${ (activemode == '2') ? "#3D5AF1" : "#E0E0E0"}" id="popup-rect-${list.formId}"/>
                                                          </svg>
                                                          </span>
                                                          <span class="gzformsembedmodetype" style ="${ (activemode == '2') ? "color:#3D5AF1;" : "color:#E0E0E0;"}" id="popup-p-${list.formId}">Popup</span>
                                                      <p>
                                                      <p class="gzformsembedmodecontent" data-index="3" data-id="${list.formId}">
                                                          <span class="gzformsembedmodeicon">
                                                          <svg width="106" height="74" viewBox="0 0 106 74" fill="none" xmlns="http://www.w3.org/2000/svg">
                                                          <rect x="0.5" y="0.5" width="105" height="73" rx="5.5" fill="white" stroke="${(activemode == '3') ? "#3D5AF1" : "#E0E0E0"}" id="slider-stroke-${list.formId}"/>
                                                          <rect x="53" y="8" width="45" height="58" rx="4" fill="${(activemode == '3') ? "#3D5AF1" : "#E0E0E0"}" id="slider-rect-${list.formId}"/>
                                                          </svg>
                                                          </span>
                                                          <span class="gzformsembedmodetype" style ="${ (activemode == '3') ? "color:#3D5AF1;" : "color:#E0E0E0;"}" id="slider-p-${list.formId}">Slider</span>
                                                      <p>
                                                      <p class="gzformsembedmodecontent"data-index="4" data-id="${list.formId}"style="margin-right:0px;">
                                                          <span class="gzformsembedmodeicon">
                                                          <svg width="106" height="74" viewBox="0 0 106 74" fill="none" xmlns="http://www.w3.org/2000/svg">
                                                          <rect x="0.5" y="0.5" width="105" height="73" rx="5.5" fill="white" stroke="${ (activemode == '4') ? "#3D5AF1" : "#E0E0E0"}" id="side-stroke-${list.formId}"/>
                                                          <rect x="62" y="12" width="36" height="50" rx="4" fill="${ (activemode == '4') ? "#3D5AF1" : "#E0E0E0"}" id="side-rect1-${list.formId}"/>
                                                          <rect x="56" y="29" width="4" height="16" rx="2" fill="${ (activemode == '4') ? "#3D5AF1" : "#E0E0E0"}" id="side-rect2-${list.formId}"/>
                                                          </svg>
                                                          </span>

                                                          <span class="gzformsembedmodetype" style ="${ (activemode == '4') ? "color:#3D5AF1;" : "color:#E0E0E0;"}" id="side-p-${list.formId}">Side Panel</span>
                                                      <p>
                                                  </div>
                                              </div>
                                              <div class="gzformsembedapperance">
                                                  <h3>Appearance</h3>
                                                  <div class="gzformapperancecontainer" id="gzformapperancecontainer${list.formId}">
                                                      <div class="gzformsembedapperanceinput" >
                                                          <span class="gzAppearancelabel"  style="margin: auto 8px;">W</span>
                                                          <div class="gzAppearanceinputval">
                                                              <input type="number" id="gzfinputwidth${list.formId}" />
                                                              <div class="gzfparam" data-id="${list.formId}" data-mode="width" data-active="deactive" >
                                                                  <span class="gzfparamicon" id="gzfparamiconwidth${list.formId}"  style="margin: auto 8px;">%</span>
                                                                  <span class="gzfparamicon"  style="margin: auto 8px;">
                                                                      <svg width="9" height="6" viewBox="0 0 9 6" fill="none" xmlns="http://www.w3.org/2000/svg">
                                                                          <path d="M7.62558 0.610357L4.64041 3.59553L1.65523 0.610357C1.35517 0.310301 0.870466 0.310301 0.57041 0.610357C0.270353 0.910414 0.270353 1.39512 0.57041 1.69518L4.10184 5.22661C4.4019 5.52667 4.88661 5.52667 5.18666 5.22661L8.71809 1.69518C9.01815 1.39512 9.01815 0.910414 8.71809 0.610357C8.41804 0.317995 7.92564 0.310301 7.62558 0.610357Z" fill="#98989A"/>
                                                                      </svg>
                                                                  </span>${setparam(['px','rem','vw'],'width',list.formId)}

                                                              </div>
                                                          </div>
                                                      </div>
                                                      <div class="gzformsembedapperanceinput">
                                                          <span class="gzAppearancelabel"  style="margin: auto 8px;">H</span>
                                                          <div class="gzAppearanceinputval">
                                                              <input type="number" id="gzfinputheight${list.formId}">
                                                              <div class="gzfparam" data-id="${list.formId}" data-mode="height" data-active="deactive">
                                                                  <span class="gzfparamicon" id="gzfparamiconheight${list.formId}" style="margin: auto 8px;">%</span>
                                                                  <span class="gzfparamicon" style="margin: auto 8px;">
                                                                      <svg width="9" height="6" viewBox="0 0 9 6" fill="none" xmlns="http://www.w3.org/2000/svg">
                                                                          <path d="M7.62558 0.610357L4.64041 3.59553L1.65523 0.610357C1.35517 0.310301 0.870466 0.310301 0.57041 0.610357C0.270353 0.910414 0.270353 1.39512 0.57041 1.69518L4.10184 5.22661C4.4019 5.52667 4.88661 5.52667 5.18666 5.22661L8.71809 1.69518C9.01815 1.39512 9.01815 0.910414 8.71809 0.610357C8.41804 0.317995 7.92564 0.310301 7.62558 0.610357Z" fill="#98989A"/>
                                                                      </svg>
                                                                  </span>${setparam(['px','rem','vw'],'height',list.formId)}
                                                              </div>
                                                          </div>
                                                      </div>
                                                  </div>
                                              </div>
                                              <div style="display:flex;width:100%;margin:1rem 0px;">
                                                  <button class="gzfprimarybnt" style="width:68%;margin:auto;margin-left:0px;" data-id="${list.formId}">
                                                  <span style="margin:auto 0.75rem;">
                                                  <svg width="14" height="9" viewBox="0 0 14 9" fill="none" xmlns="http://www.w3.org/2000/svg">
                                                  <path d="M4.52221 6.97373L1.8217 4.27322L4.52221 1.57271C4.79226 1.30266 4.79226 0.873346 4.52221 0.603295C4.25216 0.333244 3.82285 0.333244 3.55279 0.603295L0.374505 3.78159C0.104454 4.05164 0.104454 4.48787 0.374505 4.75792L3.55279 7.94314C3.82285 8.21319 4.25216 8.21319 4.52221 7.94314C4.79226 7.67309 4.79226 7.24378 4.52221 6.97373ZM9.0923 6.97373L11.7928 4.27322L9.0923 1.57271C8.82225 1.30266 8.82225 0.873346 9.0923 0.603295C9.36235 0.333244 9.79166 0.333244 10.0617 0.603295L13.24 3.78159C13.5101 4.05164 13.5101 4.48787 13.24 4.75792L10.0617 7.94314C9.79166 8.21319 9.36235 8.21319 9.0923 7.94314C8.82225 7.67309 8.82225 7.24378 9.0923 6.97373Z" fill="white"/>
                                                  </svg>

                                                  </span>
                                                  <span style="margin:auto 0px;"></span>
                                                  Get the code</button>
                                                  <button class="gzfsecondarybnt"  style="width:28%;margin:auto;margin-right:0px;" data-id="${list.formId}">Close</button>
                                              </div>
                                          </div>
                                          <div class="gzformsembedcopicontent" id="gzfcc${list.formId}" data-current-mode="htmlcode">
                                              <input type="text" id="gozenembedformcode${list.formId}" name="shortcode" value="" data-shortcode="" data-html="" />
                                              <div class="gzformsembedcopiboardbnt" id="gzfcb${list.formId}" data-id="${list.formId}">
                                                  <span class="gzformsembedcopiboardbnticon" data-id="${list.formId}">
                                                      <svg width="15" height="17" viewBox="0 0 15 17" fill="none" xmlns="http://www.w3.org/2000/svg">
                                                          <path d="M10 15H1.66667V4.16667C1.66667 3.70833 1.29167 3.33333 0.833333 3.33333C0.375 3.33333 0 3.70833 0 4.16667V15C0 15.9167 0.75 16.6667 1.66667 16.6667H10C10.4583 16.6667 10.8333 16.2917 10.8333 15.8333C10.8333 15.375 10.4583 15 10 15ZM14.1667 11.6667V1.66667C14.1667 0.75 13.4167 0 12.5 0H5C4.08333 0 3.33333 0.75 3.33333 1.66667V11.6667C3.33333 12.5833 4.08333 13.3333 5 13.3333H12.5C13.4167 13.3333 14.1667 12.5833 14.1667 11.6667ZM12.5 11.6667H5V1.66667H12.5V11.6667Z" fill="white"/>
                                                      </svg>
                                                  </span>
                                                  <p class="gzchangecodeem" id="gzchangecodeem${list.formId}" data-id="${list.formId}" data-active="deactive" data-code="html">
                                                      <span id="gzfcontent${list.formId}">HTML Code</span>

                                                      <span>
                                                          <svg width="9" height="6" viewBox="0 0 9 6" fill="none" xmlns="http://www.w3.org/2000/svg">
                                                          <path d="M7.62604 0.610418L4.64086 3.59559L1.65569 0.610418C1.35563 0.310362 0.870924 0.310362 0.570867 0.610418C0.270811 0.910475 0.270811 1.39518 0.570867 1.69524L4.1023 5.22667C4.40236 5.52673 4.88706 5.52673 5.18712 5.22667L8.71855 1.69524C9.01861 1.39518 9.01861 0.910475 8.71855 0.610418C8.4185 0.318056 7.9261 0.310362 7.62604 0.610418Z" fill="white"/>
                                                          </svg>
                                                      </span>
                                                  </p>
                                                  <p class="gzfecontentop" id="gzfcontentop${list.formId}" data-id="${list.formId}">ShortCode</p>
                                              </div>
                                          </div>

                                      </div>
                                  </div>
                                      `;



                                      function shortcode_tag(width="",height="",formId,domainId,emabedType,bntColor="",btnText="Launch",textColor="",size="",dir=""){
                                          let shortcodetag = emabedType == "standard" ? `<div id='zf-widget' data-zf-d_id='${domainId}' data-zf-id=${formId} data-zf-type='standard' style='height: ${height}; width: ${width};' ></div>` :
                                                          emabedType == "popup" ? `<button id='zf-widget' data-zf-d_id=${domainId} data-zf-id='${formId}' data-zf-type='popup' data-popup-size='${size}' > ${btnText} </button>` :
                                                          emabedType == "slider" ? `<div id='zf-widget' data-zf-d_id='${domainId}' data-zf-id='${formId}' data-zf-type='Slider' data-zf-direction='${dir}' data-zf-btn-color='${bntColor}' data-zf-btn-text-color='${textColor}' style='padding: 5px; font-size: 18px; background: ${bntColor}; color: ${textColor}; border-radius: 4px; display: inline-block;' > ${btnText} </div>` :
                                                          emabedType == "side" ? `<div id='zf-widget' data-zf-d_id='${domainId}' data-zf-id='${formId}' data-zf-type='sideTab' data-zf-btn-color='${bntColor}' data-zf-btn-text-color='${textColor}' data-zf-btn-text='${btnText}' ></div>`:"";
                                          let shortcodetitle = `gozenforms-${emabedType}-${formId}`;
                                          return {"shortcodetag":shortcodetag+`<script src="https://form-assets.forms.gozen.io/cdn/scripts/embed-v1.21.js"></script>`,"shortcodetitle":shortcodetitle,"embedtype":emabedType};
                                      
                                        }

                                      formtable.innerHTML += addtabledata;
                                      count++;

                                      function currentEmbedmodeappearance (mode,id) {

                                          let standard = `<div class="gzformapperancecontainer">
                                          <div class="gzformsembedapperanceinput">
                                              <span class="gzAppearancelabel"  style="margin: auto 8px;">W</span>
                                              <div class="gzAppearanceinputval">
                                                  <input type="number" id="gzfinputwidth${id}" />
                                                  <div class="gzfparam" data-id="${id}" data-mode="width" data-active="deactive" >
                                                      <span class="gzfparamicon" id="gzfparamiconwidth${id}" style="margin: auto 8px;">%</span>
                                                      <span class="gzfparamicon"  style="margin: auto 8px;">
                                                          <svg width="9" height="6" viewBox="0 0 9 6" fill="none" xmlns="http://www.w3.org/2000/svg">
                                                              <path d="M7.62558 0.610357L4.64041 3.59553L1.65523 0.610357C1.35517 0.310301 0.870466 0.310301 0.57041 0.610357C0.270353 0.910414 0.270353 1.39512 0.57041 1.69518L4.10184 5.22661C4.4019 5.52667 4.88661 5.52667 5.18666 5.22661L8.71809 1.69518C9.01815 1.39512 9.01815 0.910414 8.71809 0.610357C8.41804 0.317995 7.92564 0.310301 7.62558 0.610357Z" fill="#98989A"/>
                                                          </svg>
                                                      </span>${setparam(['px','rem','vw'],'width',id)}
                                                  </div>
                                              </div>
                                          </div>
                                          <div class="gzformsembedapperanceinput" >
                                              <span class="gzAppearancelabel"  style="margin: auto 8px;">H</span>
                                              <div class="gzAppearanceinputval">
                                                  <input type="number" id="gzfinputheight${id}" >
                                                  <div class="gzfparam" data-id="${id}" data-mode="height" data-active="deactive" >
                                                      <span class="gzfparamicon" id="gzfparamiconheight${id}" style="margin: auto 8px;">%</span>
                                                      <span class="gzfparamicon" style="margin: auto 8px;">
                                                          <svg width="9" height="6" viewBox="0 0 9 6" fill="none" xmlns="http://www.w3.org/2000/svg">
                                                              <path d="M7.62558 0.610357L4.64041 3.59553L1.65523 0.610357C1.35517 0.310301 0.870466 0.310301 0.57041 0.610357C0.270353 0.910414 0.270353 1.39512 0.57041 1.69518L4.10184 5.22661C4.4019 5.52667 4.88661 5.52667 5.18666 5.22661L8.71809 1.69518C9.01815 1.39512 9.01815 0.910414 8.71809 0.610357C8.41804 0.317995 7.92564 0.310301 7.62558 0.610357Z" fill="#98989A"/>
                                                          </svg>
                                                      </span>`+`${setparam(['px','rem','vw'],'height',id)}`+`
                                                  </div>
                                              </div>
                                          </div>`
                                          let popup =`

                                          <div class="gzformsembedapperanceinput">
                                              <span class="gzAppearancelabel"  style="margin: auto 8px;">Size</span>
                                              <div class="gzAppearanceinputval">
                                                  <input type="text" class="dropdowninput" id="gzfinputpopupsize${id}">
                                                  <div class="gzfparam" data-id="${id}" data-mode="popupsize" data-active="deactive">
                                                  <span class="gzfparamicon"  style="margin: auto 8px;">
                                                      <svg width="9" height="6" viewBox="0 0 9 6" fill="none" xmlns="http://www.w3.org/2000/svg">
                                                          <path d="M7.62558 0.610357L4.64041 3.59553L1.65523 0.610357C1.35517 0.310301 0.870466 0.310301 0.57041 0.610357C0.270353 0.910414 0.270353 1.39512 0.57041 1.69518L4.10184 5.22661C4.4019 5.52667 4.88661 5.52667 5.18666 5.22661L8.71809 1.69518C9.01815 1.39512 9.01815 0.910414 8.71809 0.610357C8.41804 0.317995 7.92564 0.310301 7.62558 0.610357Z" fill="#98989A"/>
                                                      </svg>
                                                  </span>`+`${setparam(['small','medium','large'],'popupsize',id)}`+`
                                              </div>
                                              </div>
                                          </div>
                                          `
                                          let slider =`

                                              <div class="gzformsembedapperanceinput">
                                                  <span class="gzAppearancelabel"  style="margin: auto 8px;">Button Color</span>
                                                  <div class="gzAppearanceinputval">
                                                      <input type="text" id="gzfinputcolor${id}" width="100%" style="border-radius:8px;width:100%;" placeholder="EX: #0c7af0"  >

                                                  </div>
                                              </div>
                                                  <div class="gzformsembedapperanceinput">
                                                  <span class="gzAppearancelabel"  style="margin: auto 8px;">Button Text Color</span>
                                                  <div class="gzAppearanceinputval">
                                                      <input type="text" id="gzfinputtc${id}" width="100%" style="border-radius:8px;width:100%;" placeholder="EX: #0c7af0" >

                                                  </div>
                                              </div>
                                              <div class="gzformsembedapperanceinput">
                                              <span class="gzAppearancelabel"  style="margin: auto 8px;">Button Text</span>
                                              <div class="gzAppearanceinputval">
                                                  <input type="text" id="gzfinputtext${id}"  width="100%" style="border-radius:8px;width:100%;" placeholder="Launch">

                                              </div>
                                          </div>
                                          <div class="gzformsembedapperanceinput">
                                              <span class="gzAppearancelabel"  style="margin: auto 8px;margin-right:28px;">Select direcion</span>
                                                  <div class="gzAppearanceinputval">
                                                      <input type="text" class="dropdowninput"  id="gzfinputsliderdir${id}" />
                                                      <div class="gzfparam" data-id="${id}" data-mode="sliderdir" data-active="deactive" >
                                                          <span  style="margin: auto 8px;">
                                                              <svg width="9" height="6" viewBox="0 0 9 6" fill="none" xmlns="http://www.w3.org/2000/svg">
                                                                  <path d="M7.62558 0.610357L4.64041 3.59553L1.65523 0.610357C1.35517 0.310301 0.870466 0.310301 0.57041 0.610357C0.270353 0.910414 0.270353 1.39512 0.57041 1.69518L4.10184 5.22661C4.4019 5.52667 4.88661 5.52667 5.18666 5.22661L8.71809 1.69518C9.01815 1.39512 9.01815 0.910414 8.71809 0.610357C8.41804 0.317995 7.92564 0.310301 7.62558 0.610357Z" fill="#98989A"/>
                                                              </svg>
                                                          </span>${setparam(['left','right'],'sliderdir',id)}
                                                      </div>
                                                  </div>
                                              </div>
                                          </div>
                                              `;
                                          let side = `
                                          <div class="gzformsembedapperanceinput">
                                              <span class="gzAppearancelabel"  style="margin: auto 8px;">Button Color</span>
                                              <div class="gzAppearanceinputval">
                                                  <input type="text" id="gzfinputcolor${id}" width="100%" style="border-radius:8px;width:100%;" placeholder="EX: #0c7af0" >

                                              </div>
                                          </div>
                                              <div class="gzformsembedapperanceinput">
                                              <span class="gzAppearancelabel"  style="margin: auto 8px;">Button Text Color</span>
                                              <div class="gzAppearanceinputval">
                                                  <input type="text" id="gzfinputtc${id}" width="100%" style="border-radius:8px;width:100%;" placeholder="EX: #0c7af0" >


                                              </div>
                                              </div>
                                          </div>
                                              <div class="gzformsembedapperanceinput">
                                              <span class="gzAppearancelabel"  style="margin: auto 8px;">Button Text</span>
                                              <div class="gzAppearanceinputval">
                                                  <input type="text" id="gzfinputtext${id}" width="100%" style="border-radius:8px;width:100%;" placeholder="Launch" >
                                              </div>
                                          </div>
                                          `;

                                          let appearancemode = mode == 'standard' ? standard : mode == 'popup' ? popup : mode == 'slider' ? slider : mode == 'side' ? side :standard ;
                                          $(`#gzformapperancecontainer${id}`).html(appearancemode);
                                          activeparam();
                                      }

                                      function activeparam(){

                                          $(".gzfparam").each( function(){
                                              $(this).click(function(e){
                                                  let bnt = $(this).attr('data-id');
                                                  let bntmode = $(this).attr('data-mode');
                                                  let butactive = $(this).attr('data-active');

                                                  if(butactive == 'active'){
                                                      $(`#gzfiop${bntmode}${bnt}`).css({'display':"none"})
                                                      $(`.gzfparamiconoptionlist`).css({'opacity':"0"})
                                                      $(this).css('border-radius','0px 8px 8px 0px')
                                                      $(this).attr('data-active','deactive')
                                                  }
                                                  else{
                                                      $(`#gzfiop${bntmode}${bnt}`).css({'display':"block"})
                                                      $(`.gzfparamiconoptionlist`).css({'opacity':"1"})
                                                      $(this).css('border-radius','0px 8px 0px 0px')
                                                      $(this).attr('data-active','active')
                                                  }
                                              })
                                          })

                                          $(`.gzfparamiconoptionlist`).each(function(){
                                              $(this).click(function(){
                                                  let bnt = $(this).attr('data-id');
                                                  let bntmode = $(this).attr('data-param');
                                                  let bnttext = $(this).text();
                                                  (bntmode == 'popupsize') ? $(`#gzfinput${bntmode}${bnt}`).val(`${bnttext}`) : (bntmode == 'sliderdir') ? $(`#gzfinput${bntmode}${bnt}`).val(`${bnttext}`) : $(`#gzfparamicon${bntmode}${bnt}`).text(`${bnttext}`) ;
                                                  $(`#gzfparamicon${bntmode}${bnt}`).text(`${bnttext}`)
                                                  $(`#gzfiopwidth${bnt}`).css({'display':"none"})
                                                  $(`#gzfiopheight${bnt}`).css({'display':"none"})
                                                  $(`.gzfparamiconoptionlist`).css({'opacity':"0"})
                                                  $(`gzfparamiconoptionlist`).attr('data-active','deactive')

                                              })
                                          })
                                      }

                                      activeparam()
                                      function currentEmbedmode ( mode ,id,index){
                                          $(`#standard-stroke-${id}`).attr("stroke",`${(mode == "standard")?"#3D5AF1":"#E0E0E0"}`)
                                          $(`#standard-rect-${id}`).attr("fill",`${(mode == "standard")?"#3D5AF1":"#E0E0E0"}`)
                                          $(`#standard-p-${id}`).css("color",`${(mode == "standard")?"#3D5AF1":"#E0E0E0"}`)
                                          $(`#popup-stroke-${id}`).attr("stroke",`${(mode == "popup")?"#3D5AF1":"#E0E0E0"}`)
                                          $(`#popup-rect-${id}`).attr("fill",`${(mode == "popup")?"#3D5AF1":"#E0E0E0"}`)
                                          $(`#popup-p-${id}`).css("color",`${(mode == "popup")?"#3D5AF1":"#E0E0E0"}`)
                                          $(`#slider-stroke-${id}`).attr("stroke",`${(mode == "slider")?"#3D5AF1":"#E0E0E0"}`)
                                          $(`#slider-rect-${id}`).attr("fill",`${(mode == "slider")?"#3D5AF1":"#E0E0E0"}`)
                                          $(`#slider-p-${id}`).css("color",`${(mode == "slider")?"#3D5AF1":"#E0E0E0"}`)
                                          $(`#side-stroke-${id}`).attr("stroke",`${(mode == "side")?"#3D5AF1":"#E0E0E0"}`)
                                          $(`#side-rect1-${id}`).attr("fill",`${(mode == "side")?"#3D5AF1":"#E0E0E0"}`)
                                          $(`#side-rect2-${id}`).attr("fill",`${(mode == "side")?"#3D5AF1":"#E0E0E0"}`)
                                          $(`#side-p-${id}`).css("color",`${(mode == "side")?"#3D5AF1":"#E0E0E0"}`)
                                          $(`#gzfem${id}`).attr("data-active-mode",`${mode}`)
                                          currentEmbedmodeappearance(mode,id)
                                      }


                                      $(".gzformsembedmodecontent").each( function(){
                                          $(this).click(function(e){
                                              let Eindex = $(this).attr('data-index');
                                              let EID = $(this).attr('data-id');
                                              let Emode = Eindex == '1' ? "standard" : Eindex == '2' ? "popup" : Eindex == '3' ? "slider" : Eindex == '4' ? "side" :"standard" ;
                                              currentEmbedmode(Emode,EID,Eindex);
                                          })

                                      })
                                      $(".gzformsembedcopiboardbnticon").each( function(){
                                          $(this).click(function(e){
                                              let copycolip = $(`#gozenembedformcode${$(this).attr('data-id')}`)
                                              let sel = copycolip.select();
                                              sel[0].setSelectionRange(0,99999);
                                              navigator.clipboard.writeText(sel.val());
                                          })

                                      })

                                      $(".gzchangecodeem").each( function (){
                                          $(this).click(function(){
                                              let psid = $(this).attr('data-id');
                                              let psstatus = $(this).attr('data-active');
                                              $(`#gzfcb${psid}`).css((psstatus == 'deactive')?{borderRadius:"0px 8px 0px 0px"}:{borderRadius:"0px 8px 8px 0px"})
                                              $(`#gzfcontentop${psid}`).css((psstatus == 'deactive')?{display:"block"}:{display:"none"})
                                              $(this).attr('data-active',(psstatus == 'deactive')?"active":"deactive");
                                          })
                                      })

                                      $(".gzfecontentop").each( function(){
                                          $(this).click(function(e){
                                              let bnt = $(this).attr('data-id');
                                              let bntcode = $(`#gzchangecodeem${bnt}`).attr('data-code');
                                              let activecodeshort =$(`#gozenembedformcode${bnt}`).attr('data-shortcode');
                                              let activecodehtml =$(`#gozenembedformcode${bnt}`).attr('data-html');
                                              $(`#gzfcontent${bnt}`).text((bntcode == 'html')?'Short Code':'HTML Code');
                                              $(`#gzfcc${bnt}`).attr('data-current-mode',(bntcode == 'html')?'shortcode':'htmlcode');
                                              $(this).text((bntcode == 'html')?'HTML Code':'Short Code');
                                              $(`#gzchangecodeem${bnt}`).attr('data-code',(bntcode == 'html')?'short':'html');
                                              $(`#gozenembedformcode${bnt}`).val((bntcode == 'html')?activecodeshort:activecodehtml);
                                              $(`#gzfcb${bnt}`).css({borderRadius:"0px 8px 8px 0px"})
                                              $(`#gzfcontentop${bnt}`).css({display:"none"})
                                              $(`#gzchangecodeem${bnt}`).attr('data-active',"deactive");
                                          })
                                      })

                                      $(".gzfomsediteroptionicon").each( function(){
                                          $(this).click(function(e){
                                              let bnt = $(this).attr('data-id');
                                              let bntmode = $(this).attr('data-mode');
                                              $(`#gzfeo${bnt}`).css('display',"flex");
                                              $(`#gzfeop${bnt}`).css('opacity',"1");
                                          })
                                      })

                                      $(".gzfeop").mouseleave(
                                          $(".gzfeop").mouseleave(function (){
                                              let bnt = $(this).attr('data-id');
                                              $(`#gzfeo${bnt}`).css('display',"none");
                                              $(`#gzfeop${bnt}`).css('opacity',"0");
                                          })
                                      )

                                      $(".gzfeop").each( function(){
                                          $(this).click(function(e){
                                              let bnt = $(this).attr('data-id');
                                              $(`#gzfeo${bnt}`).css('display',"none");
                                              $(`#gzfeop${bnt}`).css('opacity',"0");
                                          })
                                      })

                                      function Postactiveform(id,active){
                                          $.ajax({
                                              url:`${host}/wp-json/gozen-forms/v1/activecode`,
                                              type:"POST",
                                              headers:{
                                                  "forms-id": id
                                              },
                                              data:JSON.stringify({
                                                  "active":active,
                                              }),
                                              success:(res)=>{

                                                  return  (active == 0) ?"form deactive":"form active";
                                              },
                                              error:(err)=>{
                                                  alert("something Wrong!");
                                              }

                                          })
                                      }
                                      $(".Gzformsactivebutcon").each( function(){
                                          $(this).click(function(e){
                                              let bnt = $(this).attr('data-id');
                                              let butactive = $(this).attr('data-active');
                                              let setMargin = $(`#gzfas${bnt}`);
                                              setMargin.css({"margin-left":(butactive == "active")?"4px":"21px"})
                                              $(this).css({"background":(butactive == "active")?"#C1C1C2":"#2563EB"})
                                              $(this).attr('data-active',(butactive == "active")?"deactive":"active");
                                              Postactiveform(bnt,(butactive == "active")?0:1)
                                          })

                                      })


                                      $(".gzfprimarybnt").click( async function(){
                                          let dataid = $(this).attr("data-id");

                                          let width =$(`#gzfinputwidth${dataid}`).val();
                                          let wparam =$(`#gzfparamiconwidth${dataid}`).text();
                                          let height =$(`#gzfinputheight${dataid}`).val(),hparam =$(`#gzfparamiconheight${dataid}`).text();
                                          let popupsize =$(`#gzfinputpopupsize${dataid}`).val()
                                          let sliderdir =$(`#gzfinputsliderdir${dataid}`).val()
                                          let text =$(`#gzfinputtext${dataid}`).val()
                                          let tc =$(`#gzfinputtc${dataid}`).val()
                                          let color =$(`#gzfinputcolor${dataid}`).val()
                                          let code =  shortcode_tag((width=="")?"100%":`${width}${wparam}`,
                                                                      (height == "")?"500px":`${height}${hparam}`,
                                                                      dataid,
                                                                      currentdomain.id,
                                                                      $(`#gzfem${dataid}`).attr("data-active-mode"),
                                                                      (color == "")? "#2563EB" : color,
                                                                      (text == "")? "Launch" : text,
                                                                      (tc == "")? "white" : tc,
                                                                      (popupsize == "")?"small":popupsize ,
                                                                      (sliderdir =="")?'left':sliderdir);

                                          $(`gzfas${dataid}`).css({"margin-left":"21px"})
                                          $(`gzfab${dataid}`).css({"background":"#2563EB"})
                                          $(`gzfab${dataid}`).attr('data-active',"active");

                                          //shortcode_tag(width="",height="",formId,domainId,emabedType,bntColor="",btnText="Launch`",textColor="",size="",dir="")
                                          $.ajax({
                                              url:`${host}/wp-json/gozen-forms/v1/embedsc`,
                                              type:"POST",
                                              headers:{
                                                  "forms-id": $(this).attr('data-id'),
                                                  "domain-id": currentdomain.id,
                                              },
                                              data:JSON.stringify({
                                                  "emabed_type":code.embedtype,
                                                  "shortcode_title":code.shortcodetitle,
                                                  "shortcode_tag": code.shortcodetag,
                                                  "active":1,
                                              }),
                                              success:(res)=>{
                                                  console.log('form created');
                                                  let ecode = $(`#gozenembedformcode${dataid}`);
                                                  ecode.attr({"data-shortcode":`[${code.shortcodetitle}]`,"data-html":`${code.shortcodetag}`});

                                                  ($(`#gzfcc${dataid}`).attr('data-current-mode') == 'htmlcode') ? ecode.val(`${code.shortcodetag}`) : ecode.val(`[${code.shortcodetitle}]`)
                                                  return  "form created";

                                              },
                                              error:(err)=>{
                                                  alert("something Wrong!");
                                              }

                                          })

                                      })

                                      $(".close").click(function () {
                                          let dataid = $(this).attr("data-id");
                                          $(`#tb2-${dataid}`).hide();
                                      })
                                      $("button").click(function(){
                                          if($(this).attr('class') == "gzformsgetcode"){
                                              let id = $(this).attr('id');
                                              $(`#gzfe${id}`).css({"min-height": "450px","display": "flex",'opacity':"1"});
                                          }if($(this).attr('class') == "gzfsecondarybnt"){
                                              let id = $(this).attr('data-id');
                                              $(`#gzfe${id}`).css({"display": "none","min-height": "0px",'opacity':"0"});
                                          }
                                      });
                                  })
                              }
                              $(`#gzformsearch`).keyup(function(e){

                                  let currentws = formtable.getAttribute('data-activeworkspace')

                                  if(e.target.value !== "") {

                                      let getcontent = e.target.value.toLowerCase();

                                      let filtterforms = workspace[currentws].forms.filter(function(list){
                                          if(list.name.toLowerCase().startsWith(getcontent)) return list;
                                      })
                                      if(filtterforms.length != 0) createform(filtterforms)
                                      else {
                                          let adderrcontent = `
                                          <div>
                                              <h3 class="errorcontain" >Not Found</h3>
                                              <h4 class="errorcontain">Try again...<h4>
                                          </div>

                                          `
                                          formtable.innerHTML = adderrcontent;

                                      }
                                  }
                                  else createform(workspace[currentws].forms)

                              })
                          }

                      }
                  }


              },
              error: (err) => {
                  alert("something Wrong!");
                  logout();
              }
          })
      }




      $("#user-profile").click( function() {
          let active = $("#user-profile").attr('data-active');
          active == 'active' ? $("#popup-menu").hide() : $("#popup-menu").show();
          $("#user-profile").attr('data-active',active == 'active'?'deactive':'active');

      } )

      $("#popup-menu").mouseleave(
          function (){
              $("#popup-menu").hide();
          }
      )

      $

      $('#logout').click(function (){
          logout()
      })

  })
})(jQuery);
