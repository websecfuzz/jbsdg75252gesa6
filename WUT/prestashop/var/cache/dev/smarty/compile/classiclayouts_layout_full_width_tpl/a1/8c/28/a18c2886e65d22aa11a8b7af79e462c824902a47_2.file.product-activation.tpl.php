<?php
/* Smarty version 4.3.4, created on 2025-01-03 16:36:10
  from '/var/www/html/themes/classic/templates/catalog/_partials/product-activation.tpl' */

/* @var Smarty_Internal_Template $_smarty_tpl */
if ($_smarty_tpl->_decodeProperties($_smarty_tpl, array (
  'version' => '4.3.4',
  'unifunc' => 'content_6778584ac6d4a5_94598257',
  'has_nocache_code' => false,
  'file_dependency' => 
  array (
    'a18c2886e65d22aa11a8b7af79e462c824902a47' => 
    array (
      0 => '/var/www/html/themes/classic/templates/catalog/_partials/product-activation.tpl',
      1 => 1708963242,
      2 => 'file',
    ),
  ),
  'includes' => 
  array (
  ),
),false)) {
function content_6778584ac6d4a5_94598257 (Smarty_Internal_Template $_smarty_tpl) {
if ($_smarty_tpl->tpl_vars['page']->value['admin_notifications']) {?>
  <div class="alert alert-warning row" role="alert">
    <div class="container">
      <div class="row">
        <?php
$_from = $_smarty_tpl->smarty->ext->_foreach->init($_smarty_tpl, $_smarty_tpl->tpl_vars['page']->value['admin_notifications'], 'notif');
$_smarty_tpl->tpl_vars['notif']->do_else = true;
if ($_from !== null) foreach ($_from as $_smarty_tpl->tpl_vars['notif']->value) {
$_smarty_tpl->tpl_vars['notif']->do_else = false;
?>
          <div class="col-sm-12">
            <i class="material-icons float-xs-left">&#xE001;</i>
            <p class="alert-text"><?php echo htmlspecialchars((string) $_smarty_tpl->tpl_vars['notif']->value['message'], ENT_QUOTES, 'UTF-8');?>
</p>
          </div>
        <?php
}
$_smarty_tpl->smarty->ext->_foreach->restore($_smarty_tpl, 1);?>
      </div>
    </div>
  </div>
<?php }
}
}
