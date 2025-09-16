<?php
/**
 * active the Embed Script.
 */
//add_action('wp_footer','gzformEmbedScript');

//Embed script
function gzformEmbedScript(){
?>
<!--script>        
    !function ( win, doc){
        !function (e){
            const elem = doc.createElement("script");
            elem.src = e;
            doc.body.appendChild(elem);
        }("<!?php echo GOZENFORM_EMDED_SCRIPT ?>")
    }(window,document); 
</script-->
<?php
}

$forms_query = $wpdb->get_results("SELECT * FROM {$wpdb->prefix}gozen_embed_forms WHERE `active`=1");
global $forms_query;
foreach ($forms_query as $obj){

    $cb = function() use ($obj) {
        return $obj->shortcode_tag;
    };

    add_shortcode($obj->shortcode_title,$cb);
    // shortcode("$obj->shortcode_tag");
}
function shortcode($attr){

    return var_dump($attr);
   
}
/**
 * add the Embed shortcode.
 */

// add_shortcode("gozen-forms","shortcode");

// function shortcode(){
//     return 'texdtgdf';
// }
?>