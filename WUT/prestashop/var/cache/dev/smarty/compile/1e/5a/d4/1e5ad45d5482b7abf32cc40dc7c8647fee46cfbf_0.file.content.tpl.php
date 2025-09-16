<?php
/* Smarty version 4.3.4, created on 2025-01-03 16:31:16
  from '/var/www/html/admin9671czlrok7qbdn2pre/themes/new-theme/template/content.tpl' */

/* @var Smarty_Internal_Template $_smarty_tpl */
if ($_smarty_tpl->_decodeProperties($_smarty_tpl, array (
  'version' => '4.3.4',
  'unifunc' => 'content_67785724f2da39_85489042',
  'has_nocache_code' => false,
  'file_dependency' => 
  array (
    '1e5ad45d5482b7abf32cc40dc7c8647fee46cfbf' => 
    array (
      0 => '/var/www/html/admin9671czlrok7qbdn2pre/themes/new-theme/template/content.tpl',
      1 => 1727103394,
      2 => 'file',
    ),
  ),
  'includes' => 
  array (
  ),
),false)) {
function content_67785724f2da39_85489042 (Smarty_Internal_Template $_smarty_tpl) {
?>
<div id="ajax_confirmation" class="alert alert-success" style="display: none;"></div>
<div id="content-message-box"></div>


<?php if ((isset($_smarty_tpl->tpl_vars['content']->value))) {?>
  <?php echo $_smarty_tpl->tpl_vars['content']->value;?>

<?php }
}
}
