<?php
/* Smarty version 4.3.4, created on 2025-01-03 16:30:51
  from '/var/www/html/admin9671czlrok7qbdn2pre/themes/default/template/content.tpl' */

/* @var Smarty_Internal_Template $_smarty_tpl */
if ($_smarty_tpl->_decodeProperties($_smarty_tpl, array (
  'version' => '4.3.4',
  'unifunc' => 'content_6778570b583904_05090718',
  'has_nocache_code' => false,
  'file_dependency' => 
  array (
    '2c22910c865ccddbfd9219274e4e1359bb3f6169' => 
    array (
      0 => '/var/www/html/admin9671czlrok7qbdn2pre/themes/default/template/content.tpl',
      1 => 1727103394,
      2 => 'file',
    ),
  ),
  'includes' => 
  array (
  ),
),false)) {
function content_6778570b583904_05090718 (Smarty_Internal_Template $_smarty_tpl) {
?><div id="ajax_confirmation" class="alert alert-success hide"></div>
<div id="ajaxBox" style="display:none"></div>
<div id="content-message-box"></div>

<?php if ((isset($_smarty_tpl->tpl_vars['content']->value))) {?>
	<?php echo $_smarty_tpl->tpl_vars['content']->value;?>

<?php }
}
}
