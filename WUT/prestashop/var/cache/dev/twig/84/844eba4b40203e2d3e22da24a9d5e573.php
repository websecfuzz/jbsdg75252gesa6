<?php

use Twig\Environment;
use Twig\Error\LoaderError;
use Twig\Error\RuntimeError;
use Twig\Extension\SandboxExtension;
use Twig\Markup;
use Twig\Sandbox\SecurityError;
use Twig\Sandbox\SecurityNotAllowedTagError;
use Twig\Sandbox\SecurityNotAllowedFilterError;
use Twig\Sandbox\SecurityNotAllowedFunctionError;
use Twig\Source;
use Twig\Template;

/* __string_template__f9172b8d71aa35948d90359afab7219b */
class __TwigTemplate_5280446f58b0f9c64c4fec28d7c815a2 extends Template
{
    private $source;
    private $macros = [];

    public function __construct(Environment $env)
    {
        parent::__construct($env);

        $this->source = $this->getSourceContext();

        $this->parent = false;

        $this->blocks = [
            'stylesheets' => [$this, 'block_stylesheets'],
            'extra_stylesheets' => [$this, 'block_extra_stylesheets'],
            'content_header' => [$this, 'block_content_header'],
            'content' => [$this, 'block_content'],
            'content_footer' => [$this, 'block_content_footer'],
            'sidebar_right' => [$this, 'block_sidebar_right'],
            'javascripts' => [$this, 'block_javascripts'],
            'extra_javascripts' => [$this, 'block_extra_javascripts'],
            'translate_javascripts' => [$this, 'block_translate_javascripts'],
        ];
    }

    protected function doDisplay(array $context, array $blocks = [])
    {
        $macros = $this->macros;
        $__internal_5a27a8ba21ca79b61932376b2fa922d2 = $this->extensions["Symfony\\Bundle\\WebProfilerBundle\\Twig\\WebProfilerExtension"];
        $__internal_5a27a8ba21ca79b61932376b2fa922d2->enter($__internal_5a27a8ba21ca79b61932376b2fa922d2_prof = new \Twig\Profiler\Profile($this->getTemplateName(), "template", "__string_template__f9172b8d71aa35948d90359afab7219b"));

        $__internal_6f47bbe9983af81f1e7450e9a3e3768f = $this->extensions["Symfony\\Bridge\\Twig\\Extension\\ProfilerExtension"];
        $__internal_6f47bbe9983af81f1e7450e9a3e3768f->enter($__internal_6f47bbe9983af81f1e7450e9a3e3768f_prof = new \Twig\Profiler\Profile($this->getTemplateName(), "template", "__string_template__f9172b8d71aa35948d90359afab7219b"));

        // line 1
        echo "<!DOCTYPE html>
<html lang=\"en\">
<head>
  <meta charset=\"utf-8\">
<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">
<meta name=\"apple-mobile-web-app-capable\" content=\"yes\">
<meta name=\"robots\" content=\"NOFOLLOW, NOINDEX\">

<link rel=\"icon\" type=\"image/x-icon\" href=\"/img/favicon.ico\" />
<link rel=\"apple-touch-icon\" href=\"/img/app_icon.png\" />

<title>Employees • WUT</title>

  <script type=\"text/javascript\">
    var help_class_name = 'AdminEmployees';
    var iso_user = 'en';
    var lang_is_rtl = '0';
    var full_language_code = 'en-us';
    var full_cldr_language_code = 'en-US';
    var country_iso_code = 'US';
    var _PS_VERSION_ = '8.2.0';
    var roundMode = 2;
    var youEditFieldFor = '';
        var new_order_msg = 'A new order has been placed on your store.';
    var order_number_msg = 'Order number: ';
    var total_msg = 'Total: ';
    var from_msg = 'From: ';
    var see_order_msg = 'View this order';
    var new_customer_msg = 'A new customer registered on your store.';
    var customer_name_msg = 'Customer name: ';
    var new_msg = 'A new message was posted on your store.';
    var see_msg = 'Read this message';
    var token = '6b5dbd53af9cd382f82a6be5afaf60d5';
    var currentIndex = 'index.php?controller=AdminEmployees';
    var employee_token = '6b5dbd53af9cd382f82a6be5afaf60d5';
    var choose_language_translate = 'Choose language:';
    var default_language = '1';
    var admin_modules_link = '/admin9671czlrok7qbdn2pre/index.php/improve/modules/manage?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4';
    var admin_notification_get_link = '/admin9671czlrok7qbdn2pre/index.php/common/notifications?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4';
    var admin_notification_push_link = adminNotificationPushLink = '/admin9671czlrok7qbdn2pre/index.php/common/notifications/ack?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4';
    var tab_modules_list = '';
    var update_success_msg = 'Update successful';
    var search_pr";
        // line 43
        echo "oduct_msg = 'Search for a product';
  </script>



<link
      rel=\"preload\"
      href=\"/admin9671czlrok7qbdn2pre/themes/new-theme/public/2d8017489da689caedc1.preload..woff2\"
      as=\"font\"
      crossorigin
    >
      <link href=\"/admin9671czlrok7qbdn2pre/themes/new-theme/public/create_product_default_theme.css\" rel=\"stylesheet\" type=\"text/css\"/>
      <link href=\"/admin9671czlrok7qbdn2pre/themes/new-theme/public/theme.css\" rel=\"stylesheet\" type=\"text/css\"/>
      <link href=\"/js/jquery/plugins/chosen/jquery.chosen.css\" rel=\"stylesheet\" type=\"text/css\"/>
      <link href=\"/js/jquery/plugins/fancybox/jquery.fancybox.css\" rel=\"stylesheet\" type=\"text/css\"/>
      <link href=\"/modules/blockwishlist/public/backoffice.css\" rel=\"stylesheet\" type=\"text/css\"/>
      <link href=\"/admin9671czlrok7qbdn2pre/themes/default/css/vendor/nv.d3.css\" rel=\"stylesheet\" type=\"text/css\"/>
  
  <script type=\"text/javascript\">
var baseAdminDir = \"\\/admin9671czlrok7qbdn2pre\\/\";
var baseDir = \"\\/\";
var changeFormLanguageUrl = \"\\/admin9671czlrok7qbdn2pre\\/index.php\\/configure\\/advanced\\/employees\\/change-form-language?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\";
var currency = {\"iso_code\":\"USD\",\"sign\":\"\$\",\"name\":\"US Dollar\",\"format\":null};
var currency_specifications = {\"symbol\":[\".\",\",\",\";\",\"%\",\"-\",\"+\",\"E\",\"\\u00d7\",\"\\u2030\",\"\\u221e\",\"NaN\"],\"currencyCode\":\"USD\",\"currencySymbol\":\"\$\",\"numberSymbols\":[\".\",\",\",\";\",\"%\",\"-\",\"+\",\"E\",\"\\u00d7\",\"\\u2030\",\"\\u221e\",\"NaN\"],\"positivePattern\":\"\\u00a4#,##0.00\",\"negativePattern\":\"-\\u00a4#,##0.00\",\"maxFractionDigits\":2,\"minFractionDigits\":2,\"groupingUsed\":true,\"primaryGroupSize\":3,\"secondaryGroupSize\":3};
var number_specifications = {\"symbol\":[\".\",\",\",\";\",\"%\",\"-\",\"+\",\"E\",\"\\u00d7\",\"\\u2030\",\"\\u221e\",\"NaN\"],\"numberSymbols\":[\".\",\",\",\";\",\"%\",\"-\",\"+\",\"E\",\"\\u00d7\",\"\\u2030\",\"\\u221e\",\"NaN\"],\"positivePattern\":\"#,##0.###\",\"negativePattern\":\"-#,##0.###\",\"maxFractionDigits\":3,\"minFractionDigits\":0,\"groupingUsed\":true,\"primaryGroupSize\":3,\"secondaryGroupSize\":3};
v";
        // line 68
        echo "ar prestashop = {\"debug\":true};
var show_new_customers = \"1\";
var show_new_messages = \"1\";
var show_new_orders = \"1\";
</script>
<script type=\"text/javascript\" src=\"/admin9671czlrok7qbdn2pre/themes/new-theme/public/main.bundle.js\"></script>
<script type=\"text/javascript\" src=\"/js/jquery/plugins/jquery.chosen.js\"></script>
<script type=\"text/javascript\" src=\"/js/jquery/plugins/fancybox/jquery.fancybox.js\"></script>
<script type=\"text/javascript\" src=\"/js/admin.js?v=8.2.0\"></script>
<script type=\"text/javascript\" src=\"/admin9671czlrok7qbdn2pre/themes/new-theme/public/cldr.bundle.js\"></script>
<script type=\"text/javascript\" src=\"/js/tools.js?v=8.2.0\"></script>
<script type=\"text/javascript\" src=\"/admin9671czlrok7qbdn2pre/themes/new-theme/public/create_product.bundle.js\"></script>
<script type=\"text/javascript\" src=\"/modules/blockwishlist/public/vendors.js\"></script>
<script type=\"text/javascript\" src=\"/modules/ps_emailalerts/js/admin/ps_emailalerts.js\"></script>
<script type=\"text/javascript\" src=\"/js/vendor/d3.v3.min.js\"></script>
<script type=\"text/javascript\" src=\"/admin9671czlrok7qbdn2pre/themes/default/js/vendor/nv.d3.min.js\"></script>
<script type=\"text/javascript\" src=\"/modules/ps_faviconnotificationbo/views/js/favico.js\"></script>
<script type=\"text/javascript\" src=\"/modules/ps_faviconnotificationbo/views/js/ps_faviconnotificationbo.js\"></script>

  <script>
  if (undefined !== ps_faviconnotificationbo) {
    ps_faviconnotificationbo.initialize({
      backgroundColor: '#DF0067',
      textColor: '#FFFFFF',
      notificationGetUrl: '/admin9671czlrok7qbdn2pre/index.php/common/notifications?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4',
      CHECKBOX_ORDER: 1,
      CHECKBOX_CUSTOMER: 1,
      CHECKBOX_MESSAGE: 1,
      timer: 120000, // Refresh every 2 minutes
    });
  }
</script>


";
        // line 102
        $this->displayBlock('stylesheets', $context, $blocks);
        $this->displayBlock('extra_stylesheets', $context, $blocks);
        echo "</head>";
        echo "

<body
  class=\"lang-en adminemployees developer-mode\"
  data-base-url=\"/admin9671czlrok7qbdn2pre/index.php\"  data-token=\"ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\">

  <header id=\"header\" class=\"d-print-none\">

    <nav id=\"header_infos\" class=\"main-header\">
      <button class=\"btn btn-primary-reverse onclick btn-lg unbind ajax-spinner\"></button>

            <i class=\"material-icons js-mobile-menu\">menu</i>
      <a id=\"header_logo\" class=\"logo float-left\" href=\"http://localhost:8100/admin9671czlrok7qbdn2pre/index.php?controller=AdminDashboard&amp;token=b95bec1cb57a4c3a2694b03b4e02f5fb\"></a>
      <span id=\"shop_version\">8.2.0</span>

      <div class=\"component\" id=\"quick-access-container\">
        <div class=\"dropdown quick-accesses\">
  <button class=\"btn btn-link btn-sm dropdown-toggle\" type=\"button\" data-toggle=\"dropdown\" aria-haspopup=\"true\" aria-expanded=\"false\" id=\"quick_select\">
    Quick Access
  </button>
  <div class=\"dropdown-menu\">
          <a class=\"dropdown-item quick-row-link \"
         href=\"http://localhost:8100/admin9671czlrok7qbdn2pre/index.php?controller=AdminStats&amp;module=statscheckup&amp;token=03bd53e5ad9da963a1b60c654a2e1fd8\"
                 data-item=\"Catalog evaluation\"
      >Catalog evaluation</a>
          <a class=\"dropdown-item quick-row-link \"
         href=\"http://localhost:8100/admin9671czlrok7qbdn2pre/index.php/improve/modules/manage?token=1e5916c7502a3bdd12abba9e4dfa0fa2\"
                 data-item=\"Installed modules\"
      >Installed modules</a>
          <a class=\"dropdown-item quick-row-link \"
         href=\"http://localhost:8100/admin9671czlrok7qbdn2pre/index.php/sell/catalog/categories/new?token=1e5916c7502a3bdd12abba9e4dfa0fa2\"
                 data-item=\"New category\"
      >New category</a>
          <a class=\"dropdown-item quick-row-link new-product-button\"
         href=\"http://localhost:8100/admin9671czlrok7qbdn2pre/index.php/sell/catalog/products-v2/create?token=1e5916c7502a3bdd12abba9e4dfa0fa2\"
            ";
        // line 137
        echo "     data-item=\"New product\"
      >New product</a>
          <a class=\"dropdown-item quick-row-link \"
         href=\"http://localhost:8100/admin9671czlrok7qbdn2pre/index.php?controller=AdminCartRules&amp;addcart_rule&amp;token=35066e1fdaa2d26975dea7c5521c7d78\"
                 data-item=\"New voucher\"
      >New voucher</a>
          <a class=\"dropdown-item quick-row-link \"
         href=\"http://localhost:8100/admin9671czlrok7qbdn2pre/index.php/sell/orders?token=1e5916c7502a3bdd12abba9e4dfa0fa2\"
                 data-item=\"Orders\"
      >Orders</a>
        <div class=\"dropdown-divider\"></div>
          <a id=\"quick-add-link\"
        class=\"dropdown-item js-quick-link\"
        href=\"#\"
        data-rand=\"107\"
        data-icon=\"icon-AdminParentEmployees\"
        data-method=\"add\"
        data-url=\"index.php/configure/advanced/employees\"
        data-post-link=\"http://localhost:8100/admin9671czlrok7qbdn2pre/index.php?controller=AdminQuickAccesses&token=bb9f2e5d7feaeb245a11b195dc480b31\"
        data-prompt-text=\"Please name this shortcut:\"
        data-link=\"Employees - List\"
      >
        <i class=\"material-icons\">add_circle</i>
        Add current page to Quick Access
      </a>
        <a id=\"quick-manage-link\" class=\"dropdown-item\" href=\"http://localhost:8100/admin9671czlrok7qbdn2pre/index.php?controller=AdminQuickAccesses&token=bb9f2e5d7feaeb245a11b195dc480b31\">
      <i class=\"material-icons\">settings</i>
      Manage your quick accesses
    </a>
  </div>
</div>
      </div>
      <div class=\"component component-search\" id=\"header-search-container\">
        <div class=\"component-search-body\">
          <div class=\"component-search-top\">
            <form id=\"header_search\"
      class=\"bo_search_form dropdown-form js-dropdown-form collapsed\"
      method=\"post\"
      action=\"/admin9671czlrok7qbdn2pre/index.php?controller=AdminSearch&amp;token=3d2a3ae3bce709a66f0f45be5c643dd4\"
      role=\"search\">
  <input type=\"hidden\" name=\"bo_search_type\" id=\"bo_search_type\" ";
        // line 177
        echo "class=\"js-search-type\" />
    <div class=\"input-group\">
    <input type=\"text\" class=\"form-control js-form-search\" id=\"bo_query\" name=\"bo_query\" value=\"\" placeholder=\"Search (e.g.: product reference, customer name…)\" aria-label=\"Searchbar\">
    <div class=\"input-group-append\">
      <button type=\"button\" class=\"btn btn-outline-secondary dropdown-toggle js-dropdown-toggle\" data-toggle=\"dropdown\" aria-haspopup=\"true\" aria-expanded=\"false\">
        Everywhere
      </button>
      <div class=\"dropdown-menu js-items-list\">
        <a class=\"dropdown-item\" data-item=\"Everywhere\" href=\"#\" data-value=\"0\" data-placeholder=\"What are you looking for?\" data-icon=\"icon-search\"><i class=\"material-icons\">search</i> Everywhere</a>
        <div class=\"dropdown-divider\"></div>
        <a class=\"dropdown-item\" data-item=\"Catalog\" href=\"#\" data-value=\"1\" data-placeholder=\"Product name, reference, etc.\" data-icon=\"icon-book\"><i class=\"material-icons\">store_mall_directory</i> Catalog</a>
        <a class=\"dropdown-item\" data-item=\"Customers by name\" href=\"#\" data-value=\"2\" data-placeholder=\"Name\" data-icon=\"icon-group\"><i class=\"material-icons\">group</i> Customers by name</a>
        <a class=\"dropdown-item\" data-item=\"Customers by ip address\" href=\"#\" data-value=\"6\" data-placeholder=\"123.45.67.89\" data-icon=\"icon-desktop\"><i class=\"material-icons\">desktop_mac</i> Customers by IP address</a>
        <a class=\"dropdown-item\" data-item=\"Orders\" href=\"#\" data-value=\"3\" data-placeholder=\"Order ID\" data-icon=\"icon-credit-card\"><i class=\"material-icons\">shopping_basket</i> Orders</a>
        <a class=\"dropdown-item\" data-item=\"Invoices\" href=\"#\" data-value=\"4\" data-placeholder=\"Invoice number\" data-icon=\"icon-book\"><i class=\"material-icons\">book</i> Invoices</a>
        <a class=\"dropdown-item\" data-item=\"Carts\" href=\"#\" data-value=\"5\" data-placeholder=\"Cart ID\" data-icon=\"icon-shopping-cart\"><i class=\"material-icons\">shopping_cart</i> Carts</a>
        <a class=\"dropdown-item\" data-item=\"M";
        // line 193
        echo "odules\" href=\"#\" data-value=\"7\" data-placeholder=\"Module name\" data-icon=\"icon-puzzle-piece\"><i class=\"material-icons\">extension</i> Modules</a>
      </div>
      <button class=\"btn btn-primary\" type=\"submit\"><span class=\"d-none\">SEARCH</span><i class=\"material-icons\">search</i></button>
    </div>
  </div>
</form>

<script type=\"text/javascript\">
 \$(document).ready(function(){
    \$('#bo_query').one('click', function() {
    \$(this).closest('form').removeClass('collapsed');
  });
});
</script>
            <button class=\"component-search-cancel d-none\">Cancel</button>
          </div>

          <div class=\"component-search-quickaccess d-none\">
  <p class=\"component-search-title\">Quick Access</p>
      <a class=\"dropdown-item quick-row-link\"
       href=\"http://localhost:8100/admin9671czlrok7qbdn2pre/index.php?controller=AdminStats&amp;module=statscheckup&amp;token=03bd53e5ad9da963a1b60c654a2e1fd8\"
             data-item=\"Catalog evaluation\"
    >Catalog evaluation</a>
      <a class=\"dropdown-item quick-row-link\"
       href=\"http://localhost:8100/admin9671czlrok7qbdn2pre/index.php/improve/modules/manage?token=1e5916c7502a3bdd12abba9e4dfa0fa2\"
             data-item=\"Installed modules\"
    >Installed modules</a>
      <a class=\"dropdown-item quick-row-link\"
       href=\"http://localhost:8100/admin9671czlrok7qbdn2pre/index.php/sell/catalog/categories/new?token=1e5916c7502a3bdd12abba9e4dfa0fa2\"
             data-item=\"New category\"
    >New category</a>
      <a class=\"dropdown-item quick-row-link\"
       href=\"http://localhost:8100/admin9671czlrok7qbdn2pre/index.php/sell/catalog/products-v2/create?token=1e5916c7502a3bdd12abba9e4dfa0fa2\"
             data-item=\"New product\"
    >New product</a>
      <a class=\"dropdown-item quick-row-link\"
       href=\"http://localhost:8100/admin9671czlrok7qbdn2pre/index.php?controller=AdminCartRules&amp;addcart_rule&amp;token=35066e1fdaa2d26975dea7c5521c7d78\"
             data-item=\"New voucher\"
    >New voucher</a>
      <a class=";
        // line 232
        echo "\"dropdown-item quick-row-link\"
       href=\"http://localhost:8100/admin9671czlrok7qbdn2pre/index.php/sell/orders?token=1e5916c7502a3bdd12abba9e4dfa0fa2\"
             data-item=\"Orders\"
    >Orders</a>
    <div class=\"dropdown-divider\"></div>
      <a id=\"quick-add-link\"
      class=\"dropdown-item js-quick-link\"
      href=\"#\"
      data-rand=\"37\"
      data-icon=\"icon-AdminParentEmployees\"
      data-method=\"add\"
      data-url=\"index.php/configure/advanced/employees\"
      data-post-link=\"http://localhost:8100/admin9671czlrok7qbdn2pre/index.php?controller=AdminQuickAccesses&token=bb9f2e5d7feaeb245a11b195dc480b31\"
      data-prompt-text=\"Please name this shortcut:\"
      data-link=\"Employees - List\"
    >
      <i class=\"material-icons\">add_circle</i>
      Add current page to Quick Access
    </a>
    <a id=\"quick-manage-link\" class=\"dropdown-item\" href=\"http://localhost:8100/admin9671czlrok7qbdn2pre/index.php?controller=AdminQuickAccesses&token=bb9f2e5d7feaeb245a11b195dc480b31\">
    <i class=\"material-icons\">settings</i>
    Manage your quick accesses
  </a>
</div>
        </div>

        <div class=\"component-search-background d-none\"></div>
      </div>

              <div class=\"component hide-mobile-sm\" id=\"header-debug-mode-container\">
          <a class=\"link shop-state\"
             id=\"debug-mode\"
             data-toggle=\"pstooltip\"
             data-placement=\"bottom\"
             data-html=\"true\"
             title=\"<p class=&quot;text-left&quot;><strong>Your store is in debug mode.</strong></p><p class=&quot;text-left&quot;>All the PHP errors and messages are displayed. When you no longer need it, &lt;strong&gt;turn off&lt;/strong&gt; this mode.</p>\"
             href=\"/admin9671czlrok7qbdn2pre/index.php/configure/advanced/performance/?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\"
          >
            <i class=\"material-icons\">bug_report</i>
            <span>Debug mode</span>
          </a>
        </div>
      
      
      <div class=\"heade";
        // line 276
        echo "r-right\">
                  <div class=\"component\" id=\"header-shop-list-container\">
              <div class=\"shop-list\">
    <a class=\"link\" id=\"header_shopname\" href=\"http://localhost:8100/\" target= \"_blank\">
      <i class=\"material-icons\">visibility</i>
      <span>View my store</span>
    </a>
  </div>
          </div>
                          <div class=\"component header-right-component\" id=\"header-notifications-container\">
            <div id=\"notif\" class=\"notification-center dropdown dropdown-clickable\">
  <button class=\"btn notification js-notification dropdown-toggle\" data-toggle=\"dropdown\">
    <i class=\"material-icons\">notifications_none</i>
    <span id=\"notifications-total\" class=\"count hide\">0</span>
  </button>
  <div class=\"dropdown-menu dropdown-menu-right js-notifs_dropdown\">
    <div class=\"notifications\">
      <ul class=\"nav nav-tabs\" role=\"tablist\">
                          <li class=\"nav-item\">
            <a
              class=\"nav-link active\"
              id=\"orders-tab\"
              data-toggle=\"tab\"
              data-type=\"order\"
              href=\"#orders-notifications\"
              role=\"tab\"
            >
              Orders<span id=\"_nb_new_orders_\"></span>
            </a>
          </li>
                                    <li class=\"nav-item\">
            <a
              class=\"nav-link \"
              id=\"customers-tab\"
              data-toggle=\"tab\"
              data-type=\"customer\"
              href=\"#customers-notifications\"
              role=\"tab\"
            >
              Customers<span id=\"_nb_new_customers_\"></span>
            </a>
          </li>
                                    <li class=\"nav-item\">
            <a
              class=\"nav-link \"
              id=\"messages-tab\"
              data-toggle=\"tab\"
              data-type=\"customer_message\"
              href=\"#messages-notifications\"
              role=\"tab\"
            >
              Messages<span id=\"_nb_new_messages_\"></span>
         ";
        // line 328
        echo "   </a>
          </li>
                        </ul>

      <!-- Tab panes -->
      <div class=\"tab-content\">
                          <div class=\"tab-pane active empty\" id=\"orders-notifications\" role=\"tabpanel\">
            <p class=\"no-notification\">
              No new order for now :(<br>
              Have you checked your <strong><a href=\"http://localhost:8100/admin9671czlrok7qbdn2pre/index.php?controller=AdminCarts&action=filterOnlyAbandonedCarts&token=0d5ca87f77c7df188a030908f654599d\">abandoned carts</a></strong>?<br>Your next order could be hiding there!
            </p>
            <div class=\"notification-elements\"></div>
          </div>
                                    <div class=\"tab-pane  empty\" id=\"customers-notifications\" role=\"tabpanel\">
            <p class=\"no-notification\">
              No new customer for now :(<br>
              Are you active on social media these days?
            </p>
            <div class=\"notification-elements\"></div>
          </div>
                                    <div class=\"tab-pane  empty\" id=\"messages-notifications\" role=\"tabpanel\">
            <p class=\"no-notification\">
              No new message for now.<br>
              Seems like all your customers are happy :)
            </p>
            <div class=\"notification-elements\"></div>
          </div>
                        </div>
    </div>
  </div>
</div>

  <script type=\"text/html\" id=\"order-notification-template\">
    <a class=\"notif\" href='order_url'>
      #_id_order_ -
      from <strong>_customer_name_</strong> (_iso_code_)_carrier_
      <strong class=\"float-sm-right\">_total_paid_</strong>
    </a>
  </script>

  <script type=\"text/html\" id=\"customer-notification-template\">
    <a class=\"notif\" href='customer_url'>
      #_id_customer_ - <strong>_customer_name_</strong>_company_ - registered <strong>_date_add_</strong>
    </a>
  </script>

  <script type=\"text/html\" id=\"message-notification-template\">
    <a class=\"notif\" href='message_ur";
        // line 375
        echo "l'>
    <span class=\"message-notification-status _status_\">
      <i class=\"material-icons\">fiber_manual_record</i> _status_
    </span>
      - <strong>_customer_name_</strong> (_company_) - <i class=\"material-icons\">access_time</i> _date_add_
    </a>
  </script>
          </div>
        
        <div class=\"component\" id=\"header-employee-container\">
          <div class=\"dropdown employee-dropdown\">
  <div class=\"rounded-circle person\" data-toggle=\"dropdown\">
    <i class=\"material-icons\">account_circle</i>
  </div>
  <div class=\"dropdown-menu dropdown-menu-right\">
    <div class=\"employee-wrapper-avatar\">
      <div class=\"employee-top\">
        <span class=\"employee-avatar\"><img class=\"avatar rounded-circle\" src=\"http://localhost:8100/img/pr/default.jpg\" alt=\"Admin\" /></span>
        <span class=\"employee_profile\">Welcome back Admin</span>
      </div>

      <a class=\"dropdown-item employee-link profile-link\" href=\"/admin9671czlrok7qbdn2pre/index.php/configure/advanced/employees/1/edit?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\">
      <i class=\"material-icons\">edit</i>
      <span>Your profile</span>
    </a>
    </div>

    <p class=\"divider\"></p>

    
    <a class=\"dropdown-item employee-link text-center\" id=\"header_logout\" href=\"http://localhost:8100/admin9671czlrok7qbdn2pre/index.php?controller=AdminLogin&amp;logout=1&amp;token=4dd3f0fb8531fd91be44461480fde001\">
      <i class=\"material-icons d-lg-none\">power_settings_new</i>
      <span>Sign out</span>
    </a>
  </div>
</div>
        </div>
              </div>
    </nav>
  </header>

  <nav class=\"nav-bar d-none d-print-none d-md-block\">
  <span class=\"menu-collapse\" data-toggle-url=\"/admin9671czlrok7qbdn2pre/index.php/configure/advanced/employees/toggle-navigation?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\">
    <i class=\"material-icons rtl-flip\">chevron_left</i>
    <i class=\"material-icons rtl-flip\">chevron_left</i>
  </span>

  <div class=\"nav-bar-overflow\">
      <div class=\"logo-";
        // line 423
        echo "container\">
          <a id=\"header_logo\" class=\"logo float-left\" href=\"http://localhost:8100/admin9671czlrok7qbdn2pre/index.php?controller=AdminDashboard&amp;token=b95bec1cb57a4c3a2694b03b4e02f5fb\"></a>
          <span id=\"shop_version\" class=\"header-version\">8.2.0</span>
      </div>

      <ul class=\"main-menu\">
              
                    
                    
          
            <li class=\"link-levelone\" data-submenu=\"1\" id=\"tab-AdminDashboard\">
              <a href=\"http://localhost:8100/admin9671czlrok7qbdn2pre/index.php?controller=AdminDashboard&amp;token=b95bec1cb57a4c3a2694b03b4e02f5fb\" class=\"link\" >
                <i class=\"material-icons\">trending_up</i> <span>Dashboard</span>
              </a>
            </li>

          
                      
                                          
                    
          
            <li class=\"category-title\" data-submenu=\"2\" id=\"tab-SELL\">
                <span class=\"title\">Sell</span>
            </li>

                              
                  
                                                      
                  
                  <li class=\"link-levelone has_submenu\" data-submenu=\"3\" id=\"subtab-AdminParentOrders\">
                    <a href=\"/admin9671czlrok7qbdn2pre/index.php/sell/orders/?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" class=\"link\">
                      <i class=\"material-icons mi-shopping_basket\">shopping_basket</i>
                      <span>
                      Orders
                      </span>
                                                    <i class=\"material-icons sub-tabs-arrow\">
                                                                    keyboard_arrow_down
                                                            </i>
                                            </a>
                                              <ul id=\"collapse-3\" class=\"submenu panel-collapse\">
                                                      
        ";
        // line 464
        echo "                      
                                                            
                              <li class=\"link-leveltwo\" data-submenu=\"4\" id=\"subtab-AdminOrders\">
                                <a href=\"/admin9671czlrok7qbdn2pre/index.php/sell/orders/?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" class=\"link\"> Orders
                                </a>
                              </li>

                                                                                  
                              
                                                            
                              <li class=\"link-leveltwo\" data-submenu=\"5\" id=\"subtab-AdminInvoices\">
                                <a href=\"/admin9671czlrok7qbdn2pre/index.php/sell/orders/invoices/?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" class=\"link\"> Invoices
                                </a>
                              </li>

                                                                                  
                              
                                                            
                              <li class=\"link-leveltwo\" data-submenu=\"6\" id=\"subtab-AdminSlip\">
                                <a href=\"/admin9671czlrok7qbdn2pre/index.php/sell/orders/credit-slips/?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" class=\"link\"> Credit Slips
                                </a>
                              </li>

                                                                                  
                              
                                                            
                              <li class=\"link-leveltwo\" data-submenu=\"7\" id=\"subtab-AdminDeliverySlip\">
                                <a href=\"/admin9671czlrok7qbdn2pre/index.php/sell/orders/delivery-slips/?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" class=\"link\"> Delivery Slips
                                </a>
                             ";
        // line 493
        echo " </li>

                                                                                  
                              
                                                            
                              <li class=\"link-leveltwo\" data-submenu=\"8\" id=\"subtab-AdminCarts\">
                                <a href=\"http://localhost:8100/admin9671czlrok7qbdn2pre/index.php?controller=AdminCarts&amp;token=0d5ca87f77c7df188a030908f654599d\" class=\"link\"> Shopping Carts
                                </a>
                              </li>

                                                                              </ul>
                                        </li>
                                              
                  
                                                      
                  
                  <li class=\"link-levelone has_submenu\" data-submenu=\"9\" id=\"subtab-AdminCatalog\">
                    <a href=\"/admin9671czlrok7qbdn2pre/index.php/sell/catalog/products?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" class=\"link\">
                      <i class=\"material-icons mi-store\">store</i>
                      <span>
                      Catalog
                      </span>
                                                    <i class=\"material-icons sub-tabs-arrow\">
                                                                    keyboard_arrow_down
                                                            </i>
                                            </a>
                                              <ul id=\"collapse-9\" class=\"submenu panel-collapse\">
                                                      
                              
                                                            
                              <li class=\"link-leveltwo\" data-submenu=\"10\" id=\"subtab-AdminProducts\">
                                <a href=\"/admin9671czlrok7qbdn2pre/index.php/sell/catalog/products?_token=ATlXt2ftKxRdgFMQMrDdQICfh26";
        // line 524
        echo "VHYibwaRp4FSAwr4\" class=\"link\"> Products
                                </a>
                              </li>

                                                                                  
                              
                                                            
                              <li class=\"link-leveltwo\" data-submenu=\"11\" id=\"subtab-AdminCategories\">
                                <a href=\"/admin9671czlrok7qbdn2pre/index.php/sell/catalog/categories?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" class=\"link\"> Categories
                                </a>
                              </li>

                                                                                  
                              
                                                            
                              <li class=\"link-leveltwo\" data-submenu=\"12\" id=\"subtab-AdminTracking\">
                                <a href=\"/admin9671czlrok7qbdn2pre/index.php/sell/catalog/monitoring/?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" class=\"link\"> Monitoring
                                </a>
                              </li>

                                                                                  
                              
                                                            
                              <li class=\"link-leveltwo\" data-submenu=\"13\" id=\"subtab-AdminParentAttributesGroups\">
                                <a href=\"http://localhost:8100/admin9671czlrok7qbdn2pre/index.php?controller=AdminAttributesGroups&amp;token=2daf160f8f4bb2ac08f6e6efd1c42be5\" class=\"link\"> Attributes &amp; Features
                                </a>
                              </li>

                                                                                  
                              
                                                            
                              <li class=\"link-leveltwo\" data-submenu=\"16";
        // line 555
        echo "\" id=\"subtab-AdminParentManufacturers\">
                                <a href=\"/admin9671czlrok7qbdn2pre/index.php/sell/catalog/brands/?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" class=\"link\"> Brands &amp; Suppliers
                                </a>
                              </li>

                                                                                  
                              
                                                            
                              <li class=\"link-leveltwo\" data-submenu=\"19\" id=\"subtab-AdminAttachments\">
                                <a href=\"/admin9671czlrok7qbdn2pre/index.php/sell/attachments/?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" class=\"link\"> Files
                                </a>
                              </li>

                                                                                  
                              
                                                            
                              <li class=\"link-leveltwo\" data-submenu=\"20\" id=\"subtab-AdminParentCartRules\">
                                <a href=\"http://localhost:8100/admin9671czlrok7qbdn2pre/index.php?controller=AdminCartRules&amp;token=35066e1fdaa2d26975dea7c5521c7d78\" class=\"link\"> Discounts
                                </a>
                              </li>

                                                                                  
                              
                                                            
                              <li class=\"link-leveltwo\" data-submenu=\"23\" id=\"subtab-AdminStockManagement\">
                                <a href=\"/admin9671czlrok7qbdn2pre/index.php/sell/stocks/?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" class=\"link\"> Stock
                                </a>
                              </li>

                                                                              </ul>
                           ";
        // line 585
        echo "             </li>
                                              
                  
                                                      
                  
                  <li class=\"link-levelone has_submenu\" data-submenu=\"24\" id=\"subtab-AdminParentCustomer\">
                    <a href=\"/admin9671czlrok7qbdn2pre/index.php/sell/customers/?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" class=\"link\">
                      <i class=\"material-icons mi-account_circle\">account_circle</i>
                      <span>
                      Customers
                      </span>
                                                    <i class=\"material-icons sub-tabs-arrow\">
                                                                    keyboard_arrow_down
                                                            </i>
                                            </a>
                                              <ul id=\"collapse-24\" class=\"submenu panel-collapse\">
                                                      
                              
                                                            
                              <li class=\"link-leveltwo\" data-submenu=\"25\" id=\"subtab-AdminCustomers\">
                                <a href=\"/admin9671czlrok7qbdn2pre/index.php/sell/customers/?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" class=\"link\"> Customers
                                </a>
                              </li>

                                                                                  
                              
                                                            
                              <li class=\"link-leveltwo\" data-submenu=\"26\" id=\"subtab-AdminAddresses\">
                                <a href=\"/admin9671czlrok7qbdn2pre/index.php/sell/addresses/?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" class=\"link\"> Addresses
                                </a>
                              </li>

    ";
        // line 617
        echo "                                                                                                                                </ul>
                                        </li>
                                              
                  
                                                      
                  
                  <li class=\"link-levelone has_submenu\" data-submenu=\"28\" id=\"subtab-AdminParentCustomerThreads\">
                    <a href=\"http://localhost:8100/admin9671czlrok7qbdn2pre/index.php?controller=AdminCustomerThreads&amp;token=8e4778b624cce2f3558ef1de6fda99ac\" class=\"link\">
                      <i class=\"material-icons mi-chat\">chat</i>
                      <span>
                      Customer Service
                      </span>
                                                    <i class=\"material-icons sub-tabs-arrow\">
                                                                    keyboard_arrow_down
                                                            </i>
                                            </a>
                                              <ul id=\"collapse-28\" class=\"submenu panel-collapse\">
                                                      
                              
                                                            
                              <li class=\"link-leveltwo\" data-submenu=\"29\" id=\"subtab-AdminCustomerThreads\">
                                <a href=\"http://localhost:8100/admin9671czlrok7qbdn2pre/index.php?controller=AdminCustomerThreads&amp;token=8e4778b624cce2f3558ef1de6fda99ac\" class=\"link\"> Customer Service
                                </a>
                              </li>

                                                                                  
                              
                                                            
                              <li class=\"link-leveltwo\" data-submenu=\"30\" id=\"subtab-AdminOrderMessage\">
                  ";
        // line 646
        echo "              <a href=\"/admin9671czlrok7qbdn2pre/index.php/sell/customer-service/order-messages/?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" class=\"link\"> Order Messages
                                </a>
                              </li>

                                                                                  
                              
                                                            
                              <li class=\"link-leveltwo\" data-submenu=\"31\" id=\"subtab-AdminReturn\">
                                <a href=\"http://localhost:8100/admin9671czlrok7qbdn2pre/index.php?controller=AdminReturn&amp;token=86bf8977be3c26ea2502c871c132f94c\" class=\"link\"> Merchandise Returns
                                </a>
                              </li>

                                                                              </ul>
                                        </li>
                                              
                  
                                                      
                  
                  <li class=\"link-levelone\" data-submenu=\"32\" id=\"subtab-AdminStats\">
                    <a href=\"http://localhost:8100/admin9671czlrok7qbdn2pre/index.php?controller=AdminStats&amp;token=03bd53e5ad9da963a1b60c654a2e1fd8\" class=\"link\">
                      <i class=\"material-icons mi-assessment\">assessment</i>
                      <span>
                      Stats
                      </span>
                                                    <i class=\"material-icons sub-tabs-arrow\">
                                                                    keyboard_arrow_down
                                                            </i>
                                            </a>
                                        </li>
                              
          
                      
                                          
                    
          
            <li class=\"category-t";
        // line 681
        echo "itle\" data-submenu=\"37\" id=\"tab-IMPROVE\">
                <span class=\"title\">Improve</span>
            </li>

                              
                  
                                                      
                  
                  <li class=\"link-levelone has_submenu\" data-submenu=\"38\" id=\"subtab-AdminParentModulesSf\">
                    <a href=\"/admin9671czlrok7qbdn2pre/index.php/improve/modules/manage?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" class=\"link\">
                      <i class=\"material-icons mi-extension\">extension</i>
                      <span>
                      Modules
                      </span>
                                                    <i class=\"material-icons sub-tabs-arrow\">
                                                                    keyboard_arrow_down
                                                            </i>
                                            </a>
                                              <ul id=\"collapse-38\" class=\"submenu panel-collapse\">
                                                      
                              
                                                            
                              <li class=\"link-leveltwo\" data-submenu=\"39\" id=\"subtab-AdminModulesSf\">
                                <a href=\"/admin9671czlrok7qbdn2pre/index.php/improve/modules/manage?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" class=\"link\"> Module Manager
                                </a>
                              </li>

                                                                                                                                    </ul>
                                        </li>
                                              
                  
                                                      
                  
                  <li class=\"link-levelone has_submenu\" data-submenu=\"43\" id=\"subtab-AdminParentThemes\">
          ";
        // line 715
        echo "          <a href=\"/admin9671czlrok7qbdn2pre/index.php/improve/design/themes/?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" class=\"link\">
                      <i class=\"material-icons mi-desktop_mac\">desktop_mac</i>
                      <span>
                      Design
                      </span>
                                                    <i class=\"material-icons sub-tabs-arrow\">
                                                                    keyboard_arrow_down
                                                            </i>
                                            </a>
                                              <ul id=\"collapse-43\" class=\"submenu panel-collapse\">
                                                      
                              
                                                            
                              <li class=\"link-leveltwo\" data-submenu=\"128\" id=\"subtab-AdminThemesParent\">
                                <a href=\"/admin9671czlrok7qbdn2pre/index.php/improve/design/themes/?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" class=\"link\"> Theme &amp; Logo
                                </a>
                              </li>

                                                                                  
                              
                                                            
                              <li class=\"link-leveltwo\" data-submenu=\"45\" id=\"subtab-AdminParentMailTheme\">
                                <a href=\"/admin9671czlrok7qbdn2pre/index.php/improve/design/mail_theme/?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" class=\"link\"> Email Theme
                                </a>
                              </li>

                                                                                  
                              
                                                            
                              <li class=\"link-leveltwo\" data-submenu=\"";
        // line 744
        echo "47\" id=\"subtab-AdminCmsContent\">
                                <a href=\"/admin9671czlrok7qbdn2pre/index.php/improve/design/cms-pages/?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" class=\"link\"> Pages
                                </a>
                              </li>

                                                                                  
                              
                                                            
                              <li class=\"link-leveltwo\" data-submenu=\"48\" id=\"subtab-AdminModulesPositions\">
                                <a href=\"/admin9671czlrok7qbdn2pre/index.php/improve/design/modules/positions/?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" class=\"link\"> Positions
                                </a>
                              </li>

                                                                                  
                              
                                                            
                              <li class=\"link-leveltwo\" data-submenu=\"49\" id=\"subtab-AdminImages\">
                                <a href=\"http://localhost:8100/admin9671czlrok7qbdn2pre/index.php?controller=AdminImages&amp;token=8dba008ad901fccb7eeabfd3d6b26c53\" class=\"link\"> Image Settings
                                </a>
                              </li>

                                                                                  
                              
                                                            
                              <li class=\"link-leveltwo\" data-submenu=\"118\" id=\"subtab-AdminLinkWidget\">
                                <a href=\"/admin9671czlrok7qbdn2pre/index.php/modules/link-widget/list?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" class=\"link\"> Link List
                                </a>
                              </li>

                                                                              </ul>
                ";
        // line 774
        echo "                        </li>
                                              
                  
                                                      
                  
                  <li class=\"link-levelone has_submenu\" data-submenu=\"50\" id=\"subtab-AdminParentShipping\">
                    <a href=\"http://localhost:8100/admin9671czlrok7qbdn2pre/index.php?controller=AdminCarriers&amp;token=46efc14f5d6fb6399f66aa3658416d22\" class=\"link\">
                      <i class=\"material-icons mi-local_shipping\">local_shipping</i>
                      <span>
                      Shipping
                      </span>
                                                    <i class=\"material-icons sub-tabs-arrow\">
                                                                    keyboard_arrow_down
                                                            </i>
                                            </a>
                                              <ul id=\"collapse-50\" class=\"submenu panel-collapse\">
                                                      
                              
                                                            
                              <li class=\"link-leveltwo\" data-submenu=\"51\" id=\"subtab-AdminCarriers\">
                                <a href=\"http://localhost:8100/admin9671czlrok7qbdn2pre/index.php?controller=AdminCarriers&amp;token=46efc14f5d6fb6399f66aa3658416d22\" class=\"link\"> Carriers
                                </a>
                              </li>

                                                                                  
                              
                                                            
                              <li class=\"link-leveltwo\" data-submenu=\"52\" id=\"subtab-AdminShipping\">
                                <a href=\"/admin9671czlrok7qbdn2pre/index.php/improve/shipping/preferences/?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" class=\"link\"> Preferences
           ";
        // line 803
        echo "                     </a>
                              </li>

                                                                              </ul>
                                        </li>
                                              
                  
                                                      
                  
                  <li class=\"link-levelone has_submenu\" data-submenu=\"53\" id=\"subtab-AdminParentPayment\">
                    <a href=\"/admin9671czlrok7qbdn2pre/index.php/improve/payment/payment_methods?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" class=\"link\">
                      <i class=\"material-icons mi-payment\">payment</i>
                      <span>
                      Payment
                      </span>
                                                    <i class=\"material-icons sub-tabs-arrow\">
                                                                    keyboard_arrow_down
                                                            </i>
                                            </a>
                                              <ul id=\"collapse-53\" class=\"submenu panel-collapse\">
                                                      
                              
                                                            
                              <li class=\"link-leveltwo\" data-submenu=\"54\" id=\"subtab-AdminPayment\">
                                <a href=\"/admin9671czlrok7qbdn2pre/index.php/improve/payment/payment_methods?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" class=\"link\"> Payment Methods
                                </a>
                              </li>

                                                                                  
                              
                                                            
                              <li class=\"link-leveltwo\" data-submenu=\"55\" id=\"subtab-AdminPaymentPreferences\">
                                <a href=\"/adm";
        // line 835
        echo "in9671czlrok7qbdn2pre/index.php/improve/payment/preferences?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" class=\"link\"> Preferences
                                </a>
                              </li>

                                                                              </ul>
                                        </li>
                                              
                  
                                                      
                  
                  <li class=\"link-levelone has_submenu\" data-submenu=\"56\" id=\"subtab-AdminInternational\">
                    <a href=\"/admin9671czlrok7qbdn2pre/index.php/improve/international/localization/?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" class=\"link\">
                      <i class=\"material-icons mi-language\">language</i>
                      <span>
                      International
                      </span>
                                                    <i class=\"material-icons sub-tabs-arrow\">
                                                                    keyboard_arrow_down
                                                            </i>
                                            </a>
                                              <ul id=\"collapse-56\" class=\"submenu panel-collapse\">
                                                      
                              
                                                            
                              <li class=\"link-leveltwo\" data-submenu=\"57\" id=\"subtab-AdminParentLocalization\">
                                <a href=\"/admin9671czlrok7qbdn2pre/index.php/improve/international/localization/?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" class=\"link\"> Localization
                                </a>
                              </li>

                                                                                  
                              
                                            ";
        // line 866
        echo "                
                              <li class=\"link-leveltwo\" data-submenu=\"62\" id=\"subtab-AdminParentCountries\">
                                <a href=\"/admin9671czlrok7qbdn2pre/index.php/improve/international/zones/?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" class=\"link\"> Locations
                                </a>
                              </li>

                                                                                  
                              
                                                            
                              <li class=\"link-leveltwo\" data-submenu=\"66\" id=\"subtab-AdminParentTaxes\">
                                <a href=\"/admin9671czlrok7qbdn2pre/index.php/improve/international/taxes/?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" class=\"link\"> Taxes
                                </a>
                              </li>

                                                                                  
                              
                                                            
                              <li class=\"link-leveltwo\" data-submenu=\"69\" id=\"subtab-AdminTranslations\">
                                <a href=\"/admin9671czlrok7qbdn2pre/index.php/improve/international/translations/settings?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" class=\"link\"> Translations
                                </a>
                              </li>

                                                                              </ul>
                                        </li>
                              
          
                      
                                          
                    
          
            <li class=\"category-title link-active\" data-submenu=\"70\" id=\"tab-CONFIGURE\">
                <span class=\"title\">Configure</span>
            </li>

                              
                  
                                                     ";
        // line 902
        echo " 
                  
                  <li class=\"link-levelone has_submenu\" data-submenu=\"71\" id=\"subtab-ShopParameters\">
                    <a href=\"/admin9671czlrok7qbdn2pre/index.php/configure/shop/preferences/preferences?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" class=\"link\">
                      <i class=\"material-icons mi-settings\">settings</i>
                      <span>
                      Shop Parameters
                      </span>
                                                    <i class=\"material-icons sub-tabs-arrow\">
                                                                    keyboard_arrow_down
                                                            </i>
                                            </a>
                                              <ul id=\"collapse-71\" class=\"submenu panel-collapse\">
                                                      
                              
                                                            
                              <li class=\"link-leveltwo\" data-submenu=\"72\" id=\"subtab-AdminParentPreferences\">
                                <a href=\"/admin9671czlrok7qbdn2pre/index.php/configure/shop/preferences/preferences?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" class=\"link\"> General
                                </a>
                              </li>

                                                                                  
                              
                                                            
                              <li class=\"link-leveltwo\" data-submenu=\"75\" id=\"subtab-AdminParentOrderPreferences\">
                                <a href=\"/admin9671czlrok7qbdn2pre/index.php/configure/shop/order-preferences/?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" class=\"link\"> Order Settings
                                </a>
                              </li>

                                                                 ";
        // line 931
        echo "                 
                              
                                                            
                              <li class=\"link-leveltwo\" data-submenu=\"78\" id=\"subtab-AdminPPreferences\">
                                <a href=\"/admin9671czlrok7qbdn2pre/index.php/configure/shop/product-preferences/?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" class=\"link\"> Product Settings
                                </a>
                              </li>

                                                                                  
                              
                                                            
                              <li class=\"link-leveltwo\" data-submenu=\"79\" id=\"subtab-AdminParentCustomerPreferences\">
                                <a href=\"/admin9671czlrok7qbdn2pre/index.php/configure/shop/customer-preferences/?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" class=\"link\"> Customer Settings
                                </a>
                              </li>

                                                                                  
                              
                                                            
                              <li class=\"link-leveltwo\" data-submenu=\"83\" id=\"subtab-AdminParentStores\">
                                <a href=\"/admin9671czlrok7qbdn2pre/index.php/configure/shop/contacts/?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" class=\"link\"> Contact
                                </a>
                              </li>

                                                                                  
                              
                                                            
                              <li class=\"link-leveltwo\" data-submenu=\"86\" id=\"subtab-AdminParentMeta\">
                                <a href=\"/admin9671czlrok7qbdn2pre/index.php/configure/shop/seo-urls/?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibw";
        // line 959
        echo "aRp4FSAwr4\" class=\"link\"> Traffic &amp; SEO
                                </a>
                              </li>

                                                                                  
                              
                                                            
                              <li class=\"link-leveltwo\" data-submenu=\"89\" id=\"subtab-AdminParentSearchConf\">
                                <a href=\"http://localhost:8100/admin9671czlrok7qbdn2pre/index.php?controller=AdminSearchConf&amp;token=de51787e0572085c273958439c1079e9\" class=\"link\"> Search
                                </a>
                              </li>

                                                                              </ul>
                                        </li>
                                              
                  
                                                      
                                                          
                  <li class=\"link-levelone has_submenu link-active open ul-open\" data-submenu=\"92\" id=\"subtab-AdminAdvancedParameters\">
                    <a href=\"/admin9671czlrok7qbdn2pre/index.php/configure/advanced/system-information/?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" class=\"link\">
                      <i class=\"material-icons mi-settings_applications\">settings_applications</i>
                      <span>
                      Advanced Parameters
                      </span>
                                                    <i class=\"material-icons sub-tabs-arrow\">
                                                                    keyboard_arrow_up
                                                            </i>
                                            </a>
                                              <ul id=\"collapse-92\" class=\"submenu panel-collapse\">
                                                      
                              
                                       ";
        // line 990
        echo "                     
                              <li class=\"link-leveltwo\" data-submenu=\"93\" id=\"subtab-AdminInformation\">
                                <a href=\"/admin9671czlrok7qbdn2pre/index.php/configure/advanced/system-information/?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" class=\"link\"> Information
                                </a>
                              </li>

                                                                                  
                              
                                                            
                              <li class=\"link-leveltwo\" data-submenu=\"94\" id=\"subtab-AdminPerformance\">
                                <a href=\"/admin9671czlrok7qbdn2pre/index.php/configure/advanced/performance/?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" class=\"link\"> Performance
                                </a>
                              </li>

                                                                                  
                              
                                                            
                              <li class=\"link-leveltwo\" data-submenu=\"95\" id=\"subtab-AdminAdminPreferences\">
                                <a href=\"/admin9671czlrok7qbdn2pre/index.php/configure/advanced/administration/?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" class=\"link\"> Administration
                                </a>
                              </li>

                                                                                  
                              
                                                            
                              <li class=\"link-leveltwo\" data-submenu=\"96\" id=\"subtab-AdminEmails\">
                                <a href=\"/admin9671czlrok7qbdn2pre/index.php/configure/advanced/emails/?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" class=\"link\"> E-mail
                                </a>
                           ";
        // line 1018
        echo "   </li>

                                                                                  
                              
                                                            
                              <li class=\"link-leveltwo\" data-submenu=\"97\" id=\"subtab-AdminImport\">
                                <a href=\"/admin9671czlrok7qbdn2pre/index.php/configure/advanced/import/?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" class=\"link\"> Import
                                </a>
                              </li>

                                                                                  
                              
                                                            
                              <li class=\"link-leveltwo link-active\" data-submenu=\"98\" id=\"subtab-AdminParentEmployees\">
                                <a href=\"/admin9671czlrok7qbdn2pre/index.php/configure/advanced/employees/?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" class=\"link\"> Team
                                </a>
                              </li>

                                                                                  
                              
                                                            
                              <li class=\"link-leveltwo\" data-submenu=\"102\" id=\"subtab-AdminParentRequestSql\">
                                <a href=\"/admin9671czlrok7qbdn2pre/index.php/configure/advanced/sql-requests/?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" class=\"link\"> Database
                                </a>
                              </li>

                                                                                  
                              
                                                            
                              <li class=\"link-leveltwo\" data-submenu=\"105\" id=\"subtab-AdminLogs\">
                                <a href=\"/admin9671czlrok7qbdn2pre/index.php/configure/advanced/logs/";
        // line 1048
        echo "?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" class=\"link\"> Logs
                                </a>
                              </li>

                                                                                  
                              
                                                            
                              <li class=\"link-leveltwo\" data-submenu=\"106\" id=\"subtab-AdminWebservice\">
                                <a href=\"/admin9671czlrok7qbdn2pre/index.php/configure/advanced/webservice-keys/?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" class=\"link\"> Webservice
                                </a>
                              </li>

                                                                                                                                                                                                                                                    
                              
                                                            
                              <li class=\"link-leveltwo\" data-submenu=\"110\" id=\"subtab-AdminFeatureFlag\">
                                <a href=\"/admin9671czlrok7qbdn2pre/index.php/configure/advanced/feature-flags/?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" class=\"link\"> New &amp; Experimental Features
                                </a>
                              </li>

                                                                                  
                              
                                                            
                              <li class=\"link-leveltwo\" data-submenu=\"111\" id=\"subtab-AdminParentSecurity\">
                                <a href=\"/admin9671czlrok7qbdn2pre/index.php/configure/advanced/security/?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" class=\"link\"> Security
                                </a>
                              </li>

                                                ";
        // line 1076
        echo "                              </ul>
                                        </li>
                              
          
                  </ul>
  </div>
  
</nav>


<div class=\"header-toolbar d-print-none\">
    
  <div class=\"container-fluid\">

    
      <nav aria-label=\"Breadcrumb\">
        <ol class=\"breadcrumb\">
                      <li class=\"breadcrumb-item\">Team</li>
          
                      <li class=\"breadcrumb-item active\">
              <a href=\"/admin9671czlrok7qbdn2pre/index.php/configure/advanced/employees/?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" aria-current=\"page\">Employees</a>
            </li>
                  </ol>
      </nav>
    

    <div class=\"title-row\">
      
          <h1 class=\"title\">
            Employees          </h1>
      

      
        <div class=\"toolbar-icons\">
          <div class=\"wrapper\">
            
                                                          <a
                  class=\"btn btn-primary pointer\"                  id=\"page-header-desc-configuration-add\"
                  href=\"/admin9671czlrok7qbdn2pre/index.php/configure/advanced/employees/new?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\"                  title=\"Add new employee\"                                  >
                  <i class=\"material-icons\">add_circle_outline</i>                  Add new employee
                </a>
                                      
            
                              <a class=\"btn btn-outline-secondary btn-help btn-sidebar\" href=\"#\"
                   title=\"Help\"
                   data-toggle=\"sidebar\"
                   data-target=\"#right-sidebar\"
                   data-url=\"/admin9671czlrok7qbdn2pre/index.php/common/sidebar/https%253A%252F%252Fhelp.prestashop-project.org%252Fen%252Fdoc%252FAdminEmployees%253Fversion%253D8.2.0%2526country%253Den/Help?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\"
                   id=\"product_form_open_help\"
                >
         ";
        // line 1126
        echo "         Help
                </a>
                                    </div>
        </div>

      
    </div>
  </div>

  
      <div class=\"page-head-tabs\" id=\"head_tabs\">
      <ul class=\"nav nav-pills\">
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              <li class=\"nav-item\">
                    <a href=\"/admin9671czlrok7qbdn2pre/index.php/configure/advanced/employees/?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" id=\"subtab-AdminEmployees\" class=\"nav-link tab active current\" data-submenu=\"99\">
                      Employees
                      <span class=\"notification-container\">
                        <span class=\"notification-counter\"></span>
                      </";
        // line 1143
        echo "span>
                    </a>
                  </li>
                                                                <li class=\"nav-item\">
                    <a href=\"/admin9671czlrok7qbdn2pre/index.php/configure/advanced/profiles/?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" id=\"subtab-AdminProfiles\" class=\"nav-link tab \" data-submenu=\"100\">
                      Profiles
                      <span class=\"notification-container\">
                        <span class=\"notification-counter\"></span>
                      </span>
                    </a>
                  </li>
                                                                <li class=\"nav-item\">
                    <a href=\"http://localhost:8100/admin9671czlrok7qbdn2pre/index.php?controller=AdminAccess&token=b35d39da47f1ffe7898cdbf37b35ab90\" id=\"subtab-AdminAccess\" class=\"nav-link tab \" data-submenu=\"101\">
                      Permissions
                      <span class=\"notification-container\">
                        <span class=\"notification-counter\"></span>
                      </span>
                    </a>
                  </li>
                                                                                                                                                                                                                                                        </ul>
    </div>
  
  <div class=\"btn-floating\">
    <button class=\"btn btn-primary collapsed\" data-toggle=\"collapse\" data-target=\".btn-floating-container\" aria-expanded=\"false\">
      <i class=\"material-icons\">add</i>
    </button>
    <div class=\"btn-floating-container collapse\">
      <div class=\"btn-floating-menu\">
        
                              <a
              class=\"btn btn-floating-item   pointer\"              id=\"page-header-desc-floating-configuration-add\"
              href=\"/admin9671czlrok7qbdn2pre/index.php/configure/advanced/employees/new?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\"";
        // line 1174
        echo "              title=\"Add new employee\"            >
              Add new employee
              <i class=\"material-icons\">add_circle_outline</i>            </a>
                  
                              <a class=\"btn btn-floating-item btn-help btn-sidebar\" href=\"#\"
               title=\"Help\"
               data-toggle=\"sidebar\"
               data-target=\"#right-sidebar\"
               data-url=\"/admin9671czlrok7qbdn2pre/index.php/common/sidebar/https%253A%252F%252Fhelp.prestashop-project.org%252Fen%252Fdoc%252FAdminEmployees%253Fversion%253D8.2.0%2526country%253Den/Help?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\"
            >
              Help
            </a>
                        </div>
    </div>
  </div>
  
</div>

<div id=\"main-div\">
          
      <div class=\"content-div  with-tabs\">

        

                                                        
        <div id=\"ajax_confirmation\" class=\"alert alert-success\" style=\"display: none;\"></div>
<div id=\"content-message-box\"></div>


  ";
        // line 1203
        $this->displayBlock('content_header', $context, $blocks);
        $this->displayBlock('content', $context, $blocks);
        $this->displayBlock('content_footer', $context, $blocks);
        $this->displayBlock('sidebar_right', $context, $blocks);
        echo "

        

      </div>
    </div>

  <div id=\"non-responsive\" class=\"js-non-responsive\">
  <h1>Oh no!</h1>
  <p class=\"mt-3\">
    The mobile version of this page is not available yet.
  </p>
  <p class=\"mt-2\">
    Please use a desktop computer to access this page, until is adapted to mobile.
  </p>
  <p class=\"mt-2\">
    Thank you.
  </p>
  <a href=\"http://localhost:8100/admin9671czlrok7qbdn2pre/index.php?controller=AdminDashboard&amp;token=b95bec1cb57a4c3a2694b03b4e02f5fb\" class=\"btn btn-primary py-1 mt-3\">
    <i class=\"material-icons rtl-flip\">arrow_back</i>
    Back
  </a>
</div>
  <div class=\"mobile-layer\"></div>

      <div id=\"footer\" class=\"bootstrap\">
    
</div>
  

      <div class=\"bootstrap\">
      
    </div>
  
";
        // line 1237
        $this->displayBlock('javascripts', $context, $blocks);
        $this->displayBlock('extra_javascripts', $context, $blocks);
        $this->displayBlock('translate_javascripts', $context, $blocks);
        echo "</body>";
        echo "
</html>";
        
        $__internal_5a27a8ba21ca79b61932376b2fa922d2->leave($__internal_5a27a8ba21ca79b61932376b2fa922d2_prof);

        
        $__internal_6f47bbe9983af81f1e7450e9a3e3768f->leave($__internal_6f47bbe9983af81f1e7450e9a3e3768f_prof);

    }

    // line 102
    public function block_stylesheets($context, array $blocks = [])
    {
        $macros = $this->macros;
        $__internal_5a27a8ba21ca79b61932376b2fa922d2 = $this->extensions["Symfony\\Bundle\\WebProfilerBundle\\Twig\\WebProfilerExtension"];
        $__internal_5a27a8ba21ca79b61932376b2fa922d2->enter($__internal_5a27a8ba21ca79b61932376b2fa922d2_prof = new \Twig\Profiler\Profile($this->getTemplateName(), "block", "stylesheets"));

        $__internal_6f47bbe9983af81f1e7450e9a3e3768f = $this->extensions["Symfony\\Bridge\\Twig\\Extension\\ProfilerExtension"];
        $__internal_6f47bbe9983af81f1e7450e9a3e3768f->enter($__internal_6f47bbe9983af81f1e7450e9a3e3768f_prof = new \Twig\Profiler\Profile($this->getTemplateName(), "block", "stylesheets"));

        
        $__internal_6f47bbe9983af81f1e7450e9a3e3768f->leave($__internal_6f47bbe9983af81f1e7450e9a3e3768f_prof);

        
        $__internal_5a27a8ba21ca79b61932376b2fa922d2->leave($__internal_5a27a8ba21ca79b61932376b2fa922d2_prof);

    }

    public function block_extra_stylesheets($context, array $blocks = [])
    {
        $macros = $this->macros;
        $__internal_5a27a8ba21ca79b61932376b2fa922d2 = $this->extensions["Symfony\\Bundle\\WebProfilerBundle\\Twig\\WebProfilerExtension"];
        $__internal_5a27a8ba21ca79b61932376b2fa922d2->enter($__internal_5a27a8ba21ca79b61932376b2fa922d2_prof = new \Twig\Profiler\Profile($this->getTemplateName(), "block", "extra_stylesheets"));

        $__internal_6f47bbe9983af81f1e7450e9a3e3768f = $this->extensions["Symfony\\Bridge\\Twig\\Extension\\ProfilerExtension"];
        $__internal_6f47bbe9983af81f1e7450e9a3e3768f->enter($__internal_6f47bbe9983af81f1e7450e9a3e3768f_prof = new \Twig\Profiler\Profile($this->getTemplateName(), "block", "extra_stylesheets"));

        
        $__internal_6f47bbe9983af81f1e7450e9a3e3768f->leave($__internal_6f47bbe9983af81f1e7450e9a3e3768f_prof);

        
        $__internal_5a27a8ba21ca79b61932376b2fa922d2->leave($__internal_5a27a8ba21ca79b61932376b2fa922d2_prof);

    }

    // line 1203
    public function block_content_header($context, array $blocks = [])
    {
        $macros = $this->macros;
        $__internal_5a27a8ba21ca79b61932376b2fa922d2 = $this->extensions["Symfony\\Bundle\\WebProfilerBundle\\Twig\\WebProfilerExtension"];
        $__internal_5a27a8ba21ca79b61932376b2fa922d2->enter($__internal_5a27a8ba21ca79b61932376b2fa922d2_prof = new \Twig\Profiler\Profile($this->getTemplateName(), "block", "content_header"));

        $__internal_6f47bbe9983af81f1e7450e9a3e3768f = $this->extensions["Symfony\\Bridge\\Twig\\Extension\\ProfilerExtension"];
        $__internal_6f47bbe9983af81f1e7450e9a3e3768f->enter($__internal_6f47bbe9983af81f1e7450e9a3e3768f_prof = new \Twig\Profiler\Profile($this->getTemplateName(), "block", "content_header"));

        
        $__internal_6f47bbe9983af81f1e7450e9a3e3768f->leave($__internal_6f47bbe9983af81f1e7450e9a3e3768f_prof);

        
        $__internal_5a27a8ba21ca79b61932376b2fa922d2->leave($__internal_5a27a8ba21ca79b61932376b2fa922d2_prof);

    }

    public function block_content($context, array $blocks = [])
    {
        $macros = $this->macros;
        $__internal_5a27a8ba21ca79b61932376b2fa922d2 = $this->extensions["Symfony\\Bundle\\WebProfilerBundle\\Twig\\WebProfilerExtension"];
        $__internal_5a27a8ba21ca79b61932376b2fa922d2->enter($__internal_5a27a8ba21ca79b61932376b2fa922d2_prof = new \Twig\Profiler\Profile($this->getTemplateName(), "block", "content"));

        $__internal_6f47bbe9983af81f1e7450e9a3e3768f = $this->extensions["Symfony\\Bridge\\Twig\\Extension\\ProfilerExtension"];
        $__internal_6f47bbe9983af81f1e7450e9a3e3768f->enter($__internal_6f47bbe9983af81f1e7450e9a3e3768f_prof = new \Twig\Profiler\Profile($this->getTemplateName(), "block", "content"));

        
        $__internal_6f47bbe9983af81f1e7450e9a3e3768f->leave($__internal_6f47bbe9983af81f1e7450e9a3e3768f_prof);

        
        $__internal_5a27a8ba21ca79b61932376b2fa922d2->leave($__internal_5a27a8ba21ca79b61932376b2fa922d2_prof);

    }

    public function block_content_footer($context, array $blocks = [])
    {
        $macros = $this->macros;
        $__internal_5a27a8ba21ca79b61932376b2fa922d2 = $this->extensions["Symfony\\Bundle\\WebProfilerBundle\\Twig\\WebProfilerExtension"];
        $__internal_5a27a8ba21ca79b61932376b2fa922d2->enter($__internal_5a27a8ba21ca79b61932376b2fa922d2_prof = new \Twig\Profiler\Profile($this->getTemplateName(), "block", "content_footer"));

        $__internal_6f47bbe9983af81f1e7450e9a3e3768f = $this->extensions["Symfony\\Bridge\\Twig\\Extension\\ProfilerExtension"];
        $__internal_6f47bbe9983af81f1e7450e9a3e3768f->enter($__internal_6f47bbe9983af81f1e7450e9a3e3768f_prof = new \Twig\Profiler\Profile($this->getTemplateName(), "block", "content_footer"));

        
        $__internal_6f47bbe9983af81f1e7450e9a3e3768f->leave($__internal_6f47bbe9983af81f1e7450e9a3e3768f_prof);

        
        $__internal_5a27a8ba21ca79b61932376b2fa922d2->leave($__internal_5a27a8ba21ca79b61932376b2fa922d2_prof);

    }

    public function block_sidebar_right($context, array $blocks = [])
    {
        $macros = $this->macros;
        $__internal_5a27a8ba21ca79b61932376b2fa922d2 = $this->extensions["Symfony\\Bundle\\WebProfilerBundle\\Twig\\WebProfilerExtension"];
        $__internal_5a27a8ba21ca79b61932376b2fa922d2->enter($__internal_5a27a8ba21ca79b61932376b2fa922d2_prof = new \Twig\Profiler\Profile($this->getTemplateName(), "block", "sidebar_right"));

        $__internal_6f47bbe9983af81f1e7450e9a3e3768f = $this->extensions["Symfony\\Bridge\\Twig\\Extension\\ProfilerExtension"];
        $__internal_6f47bbe9983af81f1e7450e9a3e3768f->enter($__internal_6f47bbe9983af81f1e7450e9a3e3768f_prof = new \Twig\Profiler\Profile($this->getTemplateName(), "block", "sidebar_right"));

        
        $__internal_6f47bbe9983af81f1e7450e9a3e3768f->leave($__internal_6f47bbe9983af81f1e7450e9a3e3768f_prof);

        
        $__internal_5a27a8ba21ca79b61932376b2fa922d2->leave($__internal_5a27a8ba21ca79b61932376b2fa922d2_prof);

    }

    // line 1237
    public function block_javascripts($context, array $blocks = [])
    {
        $macros = $this->macros;
        $__internal_5a27a8ba21ca79b61932376b2fa922d2 = $this->extensions["Symfony\\Bundle\\WebProfilerBundle\\Twig\\WebProfilerExtension"];
        $__internal_5a27a8ba21ca79b61932376b2fa922d2->enter($__internal_5a27a8ba21ca79b61932376b2fa922d2_prof = new \Twig\Profiler\Profile($this->getTemplateName(), "block", "javascripts"));

        $__internal_6f47bbe9983af81f1e7450e9a3e3768f = $this->extensions["Symfony\\Bridge\\Twig\\Extension\\ProfilerExtension"];
        $__internal_6f47bbe9983af81f1e7450e9a3e3768f->enter($__internal_6f47bbe9983af81f1e7450e9a3e3768f_prof = new \Twig\Profiler\Profile($this->getTemplateName(), "block", "javascripts"));

        
        $__internal_6f47bbe9983af81f1e7450e9a3e3768f->leave($__internal_6f47bbe9983af81f1e7450e9a3e3768f_prof);

        
        $__internal_5a27a8ba21ca79b61932376b2fa922d2->leave($__internal_5a27a8ba21ca79b61932376b2fa922d2_prof);

    }

    public function block_extra_javascripts($context, array $blocks = [])
    {
        $macros = $this->macros;
        $__internal_5a27a8ba21ca79b61932376b2fa922d2 = $this->extensions["Symfony\\Bundle\\WebProfilerBundle\\Twig\\WebProfilerExtension"];
        $__internal_5a27a8ba21ca79b61932376b2fa922d2->enter($__internal_5a27a8ba21ca79b61932376b2fa922d2_prof = new \Twig\Profiler\Profile($this->getTemplateName(), "block", "extra_javascripts"));

        $__internal_6f47bbe9983af81f1e7450e9a3e3768f = $this->extensions["Symfony\\Bridge\\Twig\\Extension\\ProfilerExtension"];
        $__internal_6f47bbe9983af81f1e7450e9a3e3768f->enter($__internal_6f47bbe9983af81f1e7450e9a3e3768f_prof = new \Twig\Profiler\Profile($this->getTemplateName(), "block", "extra_javascripts"));

        
        $__internal_6f47bbe9983af81f1e7450e9a3e3768f->leave($__internal_6f47bbe9983af81f1e7450e9a3e3768f_prof);

        
        $__internal_5a27a8ba21ca79b61932376b2fa922d2->leave($__internal_5a27a8ba21ca79b61932376b2fa922d2_prof);

    }

    public function block_translate_javascripts($context, array $blocks = [])
    {
        $macros = $this->macros;
        $__internal_5a27a8ba21ca79b61932376b2fa922d2 = $this->extensions["Symfony\\Bundle\\WebProfilerBundle\\Twig\\WebProfilerExtension"];
        $__internal_5a27a8ba21ca79b61932376b2fa922d2->enter($__internal_5a27a8ba21ca79b61932376b2fa922d2_prof = new \Twig\Profiler\Profile($this->getTemplateName(), "block", "translate_javascripts"));

        $__internal_6f47bbe9983af81f1e7450e9a3e3768f = $this->extensions["Symfony\\Bridge\\Twig\\Extension\\ProfilerExtension"];
        $__internal_6f47bbe9983af81f1e7450e9a3e3768f->enter($__internal_6f47bbe9983af81f1e7450e9a3e3768f_prof = new \Twig\Profiler\Profile($this->getTemplateName(), "block", "translate_javascripts"));

        
        $__internal_6f47bbe9983af81f1e7450e9a3e3768f->leave($__internal_6f47bbe9983af81f1e7450e9a3e3768f_prof);

        
        $__internal_5a27a8ba21ca79b61932376b2fa922d2->leave($__internal_5a27a8ba21ca79b61932376b2fa922d2_prof);

    }

    public function getTemplateName()
    {
        return "__string_template__f9172b8d71aa35948d90359afab7219b";
    }

    public function isTraitable()
    {
        return false;
    }

    public function getDebugInfo()
    {
        return array (  1488 => 1237,  1419 => 1203,  1384 => 102,  1369 => 1237,  1329 => 1203,  1298 => 1174,  1265 => 1143,  1246 => 1126,  1194 => 1076,  1164 => 1048,  1132 => 1018,  1102 => 990,  1069 => 959,  1039 => 931,  1008 => 902,  970 => 866,  937 => 835,  903 => 803,  872 => 774,  840 => 744,  809 => 715,  773 => 681,  736 => 646,  705 => 617,  671 => 585,  639 => 555,  606 => 524,  573 => 493,  542 => 464,  499 => 423,  449 => 375,  400 => 328,  346 => 276,  300 => 232,  259 => 193,  241 => 177,  199 => 137,  159 => 102,  123 => 68,  96 => 43,  52 => 1,);
    }

    public function getSourceContext()
    {
        return new Source("{{ '<!DOCTYPE html>
<html lang=\"en\">
<head>
  <meta charset=\"utf-8\">
<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">
<meta name=\"apple-mobile-web-app-capable\" content=\"yes\">
<meta name=\"robots\" content=\"NOFOLLOW, NOINDEX\">

<link rel=\"icon\" type=\"image/x-icon\" href=\"/img/favicon.ico\" />
<link rel=\"apple-touch-icon\" href=\"/img/app_icon.png\" />

<title>Employees • WUT</title>

  <script type=\"text/javascript\">
    var help_class_name = \\'AdminEmployees\\';
    var iso_user = \\'en\\';
    var lang_is_rtl = \\'0\\';
    var full_language_code = \\'en-us\\';
    var full_cldr_language_code = \\'en-US\\';
    var country_iso_code = \\'US\\';
    var _PS_VERSION_ = \\'8.2.0\\';
    var roundMode = 2;
    var youEditFieldFor = \\'\\';
        var new_order_msg = \\'A new order has been placed on your store.\\';
    var order_number_msg = \\'Order number: \\';
    var total_msg = \\'Total: \\';
    var from_msg = \\'From: \\';
    var see_order_msg = \\'View this order\\';
    var new_customer_msg = \\'A new customer registered on your store.\\';
    var customer_name_msg = \\'Customer name: \\';
    var new_msg = \\'A new message was posted on your store.\\';
    var see_msg = \\'Read this message\\';
    var token = \\'6b5dbd53af9cd382f82a6be5afaf60d5\\';
    var currentIndex = \\'index.php?controller=AdminEmployees\\';
    var employee_token = \\'6b5dbd53af9cd382f82a6be5afaf60d5\\';
    var choose_language_translate = \\'Choose language:\\';
    var default_language = \\'1\\';
    var admin_modules_link = \\'/admin9671czlrok7qbdn2pre/index.php/improve/modules/manage?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\\';
    var admin_notification_get_link = \\'/admin9671czlrok7qbdn2pre/index.php/common/notifications?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\\';
    var admin_notification_push_link = adminNotificationPushLink = \\'/admin9671czlrok7qbdn2pre/index.php/common/notifications/ack?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\\';
    var tab_modules_list = \\'\\';
    var update_success_msg = \\'Update successful\\';
    var search_pr' | raw }}{{ 'oduct_msg = \\'Search for a product\\';
  </script>



<link
      rel=\"preload\"
      href=\"/admin9671czlrok7qbdn2pre/themes/new-theme/public/2d8017489da689caedc1.preload..woff2\"
      as=\"font\"
      crossorigin
    >
      <link href=\"/admin9671czlrok7qbdn2pre/themes/new-theme/public/create_product_default_theme.css\" rel=\"stylesheet\" type=\"text/css\"/>
      <link href=\"/admin9671czlrok7qbdn2pre/themes/new-theme/public/theme.css\" rel=\"stylesheet\" type=\"text/css\"/>
      <link href=\"/js/jquery/plugins/chosen/jquery.chosen.css\" rel=\"stylesheet\" type=\"text/css\"/>
      <link href=\"/js/jquery/plugins/fancybox/jquery.fancybox.css\" rel=\"stylesheet\" type=\"text/css\"/>
      <link href=\"/modules/blockwishlist/public/backoffice.css\" rel=\"stylesheet\" type=\"text/css\"/>
      <link href=\"/admin9671czlrok7qbdn2pre/themes/default/css/vendor/nv.d3.css\" rel=\"stylesheet\" type=\"text/css\"/>
  
  <script type=\"text/javascript\">
var baseAdminDir = \"\\\\/admin9671czlrok7qbdn2pre\\\\/\";
var baseDir = \"\\\\/\";
var changeFormLanguageUrl = \"\\\\/admin9671czlrok7qbdn2pre\\\\/index.php\\\\/configure\\\\/advanced\\\\/employees\\\\/change-form-language?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\";
var currency = {\"iso_code\":\"USD\",\"sign\":\"\$\",\"name\":\"US Dollar\",\"format\":null};
var currency_specifications = {\"symbol\":[\".\",\",\",\";\",\"%\",\"-\",\"+\",\"E\",\"\\\\u00d7\",\"\\\\u2030\",\"\\\\u221e\",\"NaN\"],\"currencyCode\":\"USD\",\"currencySymbol\":\"\$\",\"numberSymbols\":[\".\",\",\",\";\",\"%\",\"-\",\"+\",\"E\",\"\\\\u00d7\",\"\\\\u2030\",\"\\\\u221e\",\"NaN\"],\"positivePattern\":\"\\\\u00a4#,##0.00\",\"negativePattern\":\"-\\\\u00a4#,##0.00\",\"maxFractionDigits\":2,\"minFractionDigits\":2,\"groupingUsed\":true,\"primaryGroupSize\":3,\"secondaryGroupSize\":3};
var number_specifications = {\"symbol\":[\".\",\",\",\";\",\"%\",\"-\",\"+\",\"E\",\"\\\\u00d7\",\"\\\\u2030\",\"\\\\u221e\",\"NaN\"],\"numberSymbols\":[\".\",\",\",\";\",\"%\",\"-\",\"+\",\"E\",\"\\\\u00d7\",\"\\\\u2030\",\"\\\\u221e\",\"NaN\"],\"positivePattern\":\"#,##0.###\",\"negativePattern\":\"-#,##0.###\",\"maxFractionDigits\":3,\"minFractionDigits\":0,\"groupingUsed\":true,\"primaryGroupSize\":3,\"secondaryGroupSize\":3};
v' | raw }}{{ 'ar prestashop = {\"debug\":true};
var show_new_customers = \"1\";
var show_new_messages = \"1\";
var show_new_orders = \"1\";
</script>
<script type=\"text/javascript\" src=\"/admin9671czlrok7qbdn2pre/themes/new-theme/public/main.bundle.js\"></script>
<script type=\"text/javascript\" src=\"/js/jquery/plugins/jquery.chosen.js\"></script>
<script type=\"text/javascript\" src=\"/js/jquery/plugins/fancybox/jquery.fancybox.js\"></script>
<script type=\"text/javascript\" src=\"/js/admin.js?v=8.2.0\"></script>
<script type=\"text/javascript\" src=\"/admin9671czlrok7qbdn2pre/themes/new-theme/public/cldr.bundle.js\"></script>
<script type=\"text/javascript\" src=\"/js/tools.js?v=8.2.0\"></script>
<script type=\"text/javascript\" src=\"/admin9671czlrok7qbdn2pre/themes/new-theme/public/create_product.bundle.js\"></script>
<script type=\"text/javascript\" src=\"/modules/blockwishlist/public/vendors.js\"></script>
<script type=\"text/javascript\" src=\"/modules/ps_emailalerts/js/admin/ps_emailalerts.js\"></script>
<script type=\"text/javascript\" src=\"/js/vendor/d3.v3.min.js\"></script>
<script type=\"text/javascript\" src=\"/admin9671czlrok7qbdn2pre/themes/default/js/vendor/nv.d3.min.js\"></script>
<script type=\"text/javascript\" src=\"/modules/ps_faviconnotificationbo/views/js/favico.js\"></script>
<script type=\"text/javascript\" src=\"/modules/ps_faviconnotificationbo/views/js/ps_faviconnotificationbo.js\"></script>

  <script>
  if (undefined !== ps_faviconnotificationbo) {
    ps_faviconnotificationbo.initialize({
      backgroundColor: \\'#DF0067\\',
      textColor: \\'#FFFFFF\\',
      notificationGetUrl: \\'/admin9671czlrok7qbdn2pre/index.php/common/notifications?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\\',
      CHECKBOX_ORDER: 1,
      CHECKBOX_CUSTOMER: 1,
      CHECKBOX_MESSAGE: 1,
      timer: 120000, // Refresh every 2 minutes
    });
  }
</script>


' | raw }}{% block stylesheets %}{% endblock %}{% block extra_stylesheets %}{% endblock %}</head>{{ '

<body
  class=\"lang-en adminemployees developer-mode\"
  data-base-url=\"/admin9671czlrok7qbdn2pre/index.php\"  data-token=\"ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\">

  <header id=\"header\" class=\"d-print-none\">

    <nav id=\"header_infos\" class=\"main-header\">
      <button class=\"btn btn-primary-reverse onclick btn-lg unbind ajax-spinner\"></button>

            <i class=\"material-icons js-mobile-menu\">menu</i>
      <a id=\"header_logo\" class=\"logo float-left\" href=\"http://localhost:8100/admin9671czlrok7qbdn2pre/index.php?controller=AdminDashboard&amp;token=b95bec1cb57a4c3a2694b03b4e02f5fb\"></a>
      <span id=\"shop_version\">8.2.0</span>

      <div class=\"component\" id=\"quick-access-container\">
        <div class=\"dropdown quick-accesses\">
  <button class=\"btn btn-link btn-sm dropdown-toggle\" type=\"button\" data-toggle=\"dropdown\" aria-haspopup=\"true\" aria-expanded=\"false\" id=\"quick_select\">
    Quick Access
  </button>
  <div class=\"dropdown-menu\">
          <a class=\"dropdown-item quick-row-link \"
         href=\"http://localhost:8100/admin9671czlrok7qbdn2pre/index.php?controller=AdminStats&amp;module=statscheckup&amp;token=03bd53e5ad9da963a1b60c654a2e1fd8\"
                 data-item=\"Catalog evaluation\"
      >Catalog evaluation</a>
          <a class=\"dropdown-item quick-row-link \"
         href=\"http://localhost:8100/admin9671czlrok7qbdn2pre/index.php/improve/modules/manage?token=1e5916c7502a3bdd12abba9e4dfa0fa2\"
                 data-item=\"Installed modules\"
      >Installed modules</a>
          <a class=\"dropdown-item quick-row-link \"
         href=\"http://localhost:8100/admin9671czlrok7qbdn2pre/index.php/sell/catalog/categories/new?token=1e5916c7502a3bdd12abba9e4dfa0fa2\"
                 data-item=\"New category\"
      >New category</a>
          <a class=\"dropdown-item quick-row-link new-product-button\"
         href=\"http://localhost:8100/admin9671czlrok7qbdn2pre/index.php/sell/catalog/products-v2/create?token=1e5916c7502a3bdd12abba9e4dfa0fa2\"
            ' | raw }}{{ '     data-item=\"New product\"
      >New product</a>
          <a class=\"dropdown-item quick-row-link \"
         href=\"http://localhost:8100/admin9671czlrok7qbdn2pre/index.php?controller=AdminCartRules&amp;addcart_rule&amp;token=35066e1fdaa2d26975dea7c5521c7d78\"
                 data-item=\"New voucher\"
      >New voucher</a>
          <a class=\"dropdown-item quick-row-link \"
         href=\"http://localhost:8100/admin9671czlrok7qbdn2pre/index.php/sell/orders?token=1e5916c7502a3bdd12abba9e4dfa0fa2\"
                 data-item=\"Orders\"
      >Orders</a>
        <div class=\"dropdown-divider\"></div>
          <a id=\"quick-add-link\"
        class=\"dropdown-item js-quick-link\"
        href=\"#\"
        data-rand=\"107\"
        data-icon=\"icon-AdminParentEmployees\"
        data-method=\"add\"
        data-url=\"index.php/configure/advanced/employees\"
        data-post-link=\"http://localhost:8100/admin9671czlrok7qbdn2pre/index.php?controller=AdminQuickAccesses&token=bb9f2e5d7feaeb245a11b195dc480b31\"
        data-prompt-text=\"Please name this shortcut:\"
        data-link=\"Employees - List\"
      >
        <i class=\"material-icons\">add_circle</i>
        Add current page to Quick Access
      </a>
        <a id=\"quick-manage-link\" class=\"dropdown-item\" href=\"http://localhost:8100/admin9671czlrok7qbdn2pre/index.php?controller=AdminQuickAccesses&token=bb9f2e5d7feaeb245a11b195dc480b31\">
      <i class=\"material-icons\">settings</i>
      Manage your quick accesses
    </a>
  </div>
</div>
      </div>
      <div class=\"component component-search\" id=\"header-search-container\">
        <div class=\"component-search-body\">
          <div class=\"component-search-top\">
            <form id=\"header_search\"
      class=\"bo_search_form dropdown-form js-dropdown-form collapsed\"
      method=\"post\"
      action=\"/admin9671czlrok7qbdn2pre/index.php?controller=AdminSearch&amp;token=3d2a3ae3bce709a66f0f45be5c643dd4\"
      role=\"search\">
  <input type=\"hidden\" name=\"bo_search_type\" id=\"bo_search_type\" ' | raw }}{{ 'class=\"js-search-type\" />
    <div class=\"input-group\">
    <input type=\"text\" class=\"form-control js-form-search\" id=\"bo_query\" name=\"bo_query\" value=\"\" placeholder=\"Search (e.g.: product reference, customer name…)\" aria-label=\"Searchbar\">
    <div class=\"input-group-append\">
      <button type=\"button\" class=\"btn btn-outline-secondary dropdown-toggle js-dropdown-toggle\" data-toggle=\"dropdown\" aria-haspopup=\"true\" aria-expanded=\"false\">
        Everywhere
      </button>
      <div class=\"dropdown-menu js-items-list\">
        <a class=\"dropdown-item\" data-item=\"Everywhere\" href=\"#\" data-value=\"0\" data-placeholder=\"What are you looking for?\" data-icon=\"icon-search\"><i class=\"material-icons\">search</i> Everywhere</a>
        <div class=\"dropdown-divider\"></div>
        <a class=\"dropdown-item\" data-item=\"Catalog\" href=\"#\" data-value=\"1\" data-placeholder=\"Product name, reference, etc.\" data-icon=\"icon-book\"><i class=\"material-icons\">store_mall_directory</i> Catalog</a>
        <a class=\"dropdown-item\" data-item=\"Customers by name\" href=\"#\" data-value=\"2\" data-placeholder=\"Name\" data-icon=\"icon-group\"><i class=\"material-icons\">group</i> Customers by name</a>
        <a class=\"dropdown-item\" data-item=\"Customers by ip address\" href=\"#\" data-value=\"6\" data-placeholder=\"123.45.67.89\" data-icon=\"icon-desktop\"><i class=\"material-icons\">desktop_mac</i> Customers by IP address</a>
        <a class=\"dropdown-item\" data-item=\"Orders\" href=\"#\" data-value=\"3\" data-placeholder=\"Order ID\" data-icon=\"icon-credit-card\"><i class=\"material-icons\">shopping_basket</i> Orders</a>
        <a class=\"dropdown-item\" data-item=\"Invoices\" href=\"#\" data-value=\"4\" data-placeholder=\"Invoice number\" data-icon=\"icon-book\"><i class=\"material-icons\">book</i> Invoices</a>
        <a class=\"dropdown-item\" data-item=\"Carts\" href=\"#\" data-value=\"5\" data-placeholder=\"Cart ID\" data-icon=\"icon-shopping-cart\"><i class=\"material-icons\">shopping_cart</i> Carts</a>
        <a class=\"dropdown-item\" data-item=\"M' | raw }}{{ 'odules\" href=\"#\" data-value=\"7\" data-placeholder=\"Module name\" data-icon=\"icon-puzzle-piece\"><i class=\"material-icons\">extension</i> Modules</a>
      </div>
      <button class=\"btn btn-primary\" type=\"submit\"><span class=\"d-none\">SEARCH</span><i class=\"material-icons\">search</i></button>
    </div>
  </div>
</form>

<script type=\"text/javascript\">
 \$(document).ready(function(){
    \$(\\'#bo_query\\').one(\\'click\\', function() {
    \$(this).closest(\\'form\\').removeClass(\\'collapsed\\');
  });
});
</script>
            <button class=\"component-search-cancel d-none\">Cancel</button>
          </div>

          <div class=\"component-search-quickaccess d-none\">
  <p class=\"component-search-title\">Quick Access</p>
      <a class=\"dropdown-item quick-row-link\"
       href=\"http://localhost:8100/admin9671czlrok7qbdn2pre/index.php?controller=AdminStats&amp;module=statscheckup&amp;token=03bd53e5ad9da963a1b60c654a2e1fd8\"
             data-item=\"Catalog evaluation\"
    >Catalog evaluation</a>
      <a class=\"dropdown-item quick-row-link\"
       href=\"http://localhost:8100/admin9671czlrok7qbdn2pre/index.php/improve/modules/manage?token=1e5916c7502a3bdd12abba9e4dfa0fa2\"
             data-item=\"Installed modules\"
    >Installed modules</a>
      <a class=\"dropdown-item quick-row-link\"
       href=\"http://localhost:8100/admin9671czlrok7qbdn2pre/index.php/sell/catalog/categories/new?token=1e5916c7502a3bdd12abba9e4dfa0fa2\"
             data-item=\"New category\"
    >New category</a>
      <a class=\"dropdown-item quick-row-link\"
       href=\"http://localhost:8100/admin9671czlrok7qbdn2pre/index.php/sell/catalog/products-v2/create?token=1e5916c7502a3bdd12abba9e4dfa0fa2\"
             data-item=\"New product\"
    >New product</a>
      <a class=\"dropdown-item quick-row-link\"
       href=\"http://localhost:8100/admin9671czlrok7qbdn2pre/index.php?controller=AdminCartRules&amp;addcart_rule&amp;token=35066e1fdaa2d26975dea7c5521c7d78\"
             data-item=\"New voucher\"
    >New voucher</a>
      <a class=' | raw }}{{ '\"dropdown-item quick-row-link\"
       href=\"http://localhost:8100/admin9671czlrok7qbdn2pre/index.php/sell/orders?token=1e5916c7502a3bdd12abba9e4dfa0fa2\"
             data-item=\"Orders\"
    >Orders</a>
    <div class=\"dropdown-divider\"></div>
      <a id=\"quick-add-link\"
      class=\"dropdown-item js-quick-link\"
      href=\"#\"
      data-rand=\"37\"
      data-icon=\"icon-AdminParentEmployees\"
      data-method=\"add\"
      data-url=\"index.php/configure/advanced/employees\"
      data-post-link=\"http://localhost:8100/admin9671czlrok7qbdn2pre/index.php?controller=AdminQuickAccesses&token=bb9f2e5d7feaeb245a11b195dc480b31\"
      data-prompt-text=\"Please name this shortcut:\"
      data-link=\"Employees - List\"
    >
      <i class=\"material-icons\">add_circle</i>
      Add current page to Quick Access
    </a>
    <a id=\"quick-manage-link\" class=\"dropdown-item\" href=\"http://localhost:8100/admin9671czlrok7qbdn2pre/index.php?controller=AdminQuickAccesses&token=bb9f2e5d7feaeb245a11b195dc480b31\">
    <i class=\"material-icons\">settings</i>
    Manage your quick accesses
  </a>
</div>
        </div>

        <div class=\"component-search-background d-none\"></div>
      </div>

              <div class=\"component hide-mobile-sm\" id=\"header-debug-mode-container\">
          <a class=\"link shop-state\"
             id=\"debug-mode\"
             data-toggle=\"pstooltip\"
             data-placement=\"bottom\"
             data-html=\"true\"
             title=\"<p class=&quot;text-left&quot;><strong>Your store is in debug mode.</strong></p><p class=&quot;text-left&quot;>All the PHP errors and messages are displayed. When you no longer need it, &lt;strong&gt;turn off&lt;/strong&gt; this mode.</p>\"
             href=\"/admin9671czlrok7qbdn2pre/index.php/configure/advanced/performance/?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\"
          >
            <i class=\"material-icons\">bug_report</i>
            <span>Debug mode</span>
          </a>
        </div>
      
      
      <div class=\"heade' | raw }}{{ 'r-right\">
                  <div class=\"component\" id=\"header-shop-list-container\">
              <div class=\"shop-list\">
    <a class=\"link\" id=\"header_shopname\" href=\"http://localhost:8100/\" target= \"_blank\">
      <i class=\"material-icons\">visibility</i>
      <span>View my store</span>
    </a>
  </div>
          </div>
                          <div class=\"component header-right-component\" id=\"header-notifications-container\">
            <div id=\"notif\" class=\"notification-center dropdown dropdown-clickable\">
  <button class=\"btn notification js-notification dropdown-toggle\" data-toggle=\"dropdown\">
    <i class=\"material-icons\">notifications_none</i>
    <span id=\"notifications-total\" class=\"count hide\">0</span>
  </button>
  <div class=\"dropdown-menu dropdown-menu-right js-notifs_dropdown\">
    <div class=\"notifications\">
      <ul class=\"nav nav-tabs\" role=\"tablist\">
                          <li class=\"nav-item\">
            <a
              class=\"nav-link active\"
              id=\"orders-tab\"
              data-toggle=\"tab\"
              data-type=\"order\"
              href=\"#orders-notifications\"
              role=\"tab\"
            >
              Orders<span id=\"_nb_new_orders_\"></span>
            </a>
          </li>
                                    <li class=\"nav-item\">
            <a
              class=\"nav-link \"
              id=\"customers-tab\"
              data-toggle=\"tab\"
              data-type=\"customer\"
              href=\"#customers-notifications\"
              role=\"tab\"
            >
              Customers<span id=\"_nb_new_customers_\"></span>
            </a>
          </li>
                                    <li class=\"nav-item\">
            <a
              class=\"nav-link \"
              id=\"messages-tab\"
              data-toggle=\"tab\"
              data-type=\"customer_message\"
              href=\"#messages-notifications\"
              role=\"tab\"
            >
              Messages<span id=\"_nb_new_messages_\"></span>
         ' | raw }}{{ '   </a>
          </li>
                        </ul>

      <!-- Tab panes -->
      <div class=\"tab-content\">
                          <div class=\"tab-pane active empty\" id=\"orders-notifications\" role=\"tabpanel\">
            <p class=\"no-notification\">
              No new order for now :(<br>
              Have you checked your <strong><a href=\"http://localhost:8100/admin9671czlrok7qbdn2pre/index.php?controller=AdminCarts&action=filterOnlyAbandonedCarts&token=0d5ca87f77c7df188a030908f654599d\">abandoned carts</a></strong>?<br>Your next order could be hiding there!
            </p>
            <div class=\"notification-elements\"></div>
          </div>
                                    <div class=\"tab-pane  empty\" id=\"customers-notifications\" role=\"tabpanel\">
            <p class=\"no-notification\">
              No new customer for now :(<br>
              Are you active on social media these days?
            </p>
            <div class=\"notification-elements\"></div>
          </div>
                                    <div class=\"tab-pane  empty\" id=\"messages-notifications\" role=\"tabpanel\">
            <p class=\"no-notification\">
              No new message for now.<br>
              Seems like all your customers are happy :)
            </p>
            <div class=\"notification-elements\"></div>
          </div>
                        </div>
    </div>
  </div>
</div>

  <script type=\"text/html\" id=\"order-notification-template\">
    <a class=\"notif\" href=\\'order_url\\'>
      #_id_order_ -
      from <strong>_customer_name_</strong> (_iso_code_)_carrier_
      <strong class=\"float-sm-right\">_total_paid_</strong>
    </a>
  </script>

  <script type=\"text/html\" id=\"customer-notification-template\">
    <a class=\"notif\" href=\\'customer_url\\'>
      #_id_customer_ - <strong>_customer_name_</strong>_company_ - registered <strong>_date_add_</strong>
    </a>
  </script>

  <script type=\"text/html\" id=\"message-notification-template\">
    <a class=\"notif\" href=\\'message_ur' | raw }}{{ 'l\\'>
    <span class=\"message-notification-status _status_\">
      <i class=\"material-icons\">fiber_manual_record</i> _status_
    </span>
      - <strong>_customer_name_</strong> (_company_) - <i class=\"material-icons\">access_time</i> _date_add_
    </a>
  </script>
          </div>
        
        <div class=\"component\" id=\"header-employee-container\">
          <div class=\"dropdown employee-dropdown\">
  <div class=\"rounded-circle person\" data-toggle=\"dropdown\">
    <i class=\"material-icons\">account_circle</i>
  </div>
  <div class=\"dropdown-menu dropdown-menu-right\">
    <div class=\"employee-wrapper-avatar\">
      <div class=\"employee-top\">
        <span class=\"employee-avatar\"><img class=\"avatar rounded-circle\" src=\"http://localhost:8100/img/pr/default.jpg\" alt=\"Admin\" /></span>
        <span class=\"employee_profile\">Welcome back Admin</span>
      </div>

      <a class=\"dropdown-item employee-link profile-link\" href=\"/admin9671czlrok7qbdn2pre/index.php/configure/advanced/employees/1/edit?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\">
      <i class=\"material-icons\">edit</i>
      <span>Your profile</span>
    </a>
    </div>

    <p class=\"divider\"></p>

    
    <a class=\"dropdown-item employee-link text-center\" id=\"header_logout\" href=\"http://localhost:8100/admin9671czlrok7qbdn2pre/index.php?controller=AdminLogin&amp;logout=1&amp;token=4dd3f0fb8531fd91be44461480fde001\">
      <i class=\"material-icons d-lg-none\">power_settings_new</i>
      <span>Sign out</span>
    </a>
  </div>
</div>
        </div>
              </div>
    </nav>
  </header>

  <nav class=\"nav-bar d-none d-print-none d-md-block\">
  <span class=\"menu-collapse\" data-toggle-url=\"/admin9671czlrok7qbdn2pre/index.php/configure/advanced/employees/toggle-navigation?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\">
    <i class=\"material-icons rtl-flip\">chevron_left</i>
    <i class=\"material-icons rtl-flip\">chevron_left</i>
  </span>

  <div class=\"nav-bar-overflow\">
      <div class=\"logo-' | raw }}{{ 'container\">
          <a id=\"header_logo\" class=\"logo float-left\" href=\"http://localhost:8100/admin9671czlrok7qbdn2pre/index.php?controller=AdminDashboard&amp;token=b95bec1cb57a4c3a2694b03b4e02f5fb\"></a>
          <span id=\"shop_version\" class=\"header-version\">8.2.0</span>
      </div>

      <ul class=\"main-menu\">
              
                    
                    
          
            <li class=\"link-levelone\" data-submenu=\"1\" id=\"tab-AdminDashboard\">
              <a href=\"http://localhost:8100/admin9671czlrok7qbdn2pre/index.php?controller=AdminDashboard&amp;token=b95bec1cb57a4c3a2694b03b4e02f5fb\" class=\"link\" >
                <i class=\"material-icons\">trending_up</i> <span>Dashboard</span>
              </a>
            </li>

          
                      
                                          
                    
          
            <li class=\"category-title\" data-submenu=\"2\" id=\"tab-SELL\">
                <span class=\"title\">Sell</span>
            </li>

                              
                  
                                                      
                  
                  <li class=\"link-levelone has_submenu\" data-submenu=\"3\" id=\"subtab-AdminParentOrders\">
                    <a href=\"/admin9671czlrok7qbdn2pre/index.php/sell/orders/?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" class=\"link\">
                      <i class=\"material-icons mi-shopping_basket\">shopping_basket</i>
                      <span>
                      Orders
                      </span>
                                                    <i class=\"material-icons sub-tabs-arrow\">
                                                                    keyboard_arrow_down
                                                            </i>
                                            </a>
                                              <ul id=\"collapse-3\" class=\"submenu panel-collapse\">
                                                      
        ' | raw }}{{ '                      
                                                            
                              <li class=\"link-leveltwo\" data-submenu=\"4\" id=\"subtab-AdminOrders\">
                                <a href=\"/admin9671czlrok7qbdn2pre/index.php/sell/orders/?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" class=\"link\"> Orders
                                </a>
                              </li>

                                                                                  
                              
                                                            
                              <li class=\"link-leveltwo\" data-submenu=\"5\" id=\"subtab-AdminInvoices\">
                                <a href=\"/admin9671czlrok7qbdn2pre/index.php/sell/orders/invoices/?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" class=\"link\"> Invoices
                                </a>
                              </li>

                                                                                  
                              
                                                            
                              <li class=\"link-leveltwo\" data-submenu=\"6\" id=\"subtab-AdminSlip\">
                                <a href=\"/admin9671czlrok7qbdn2pre/index.php/sell/orders/credit-slips/?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" class=\"link\"> Credit Slips
                                </a>
                              </li>

                                                                                  
                              
                                                            
                              <li class=\"link-leveltwo\" data-submenu=\"7\" id=\"subtab-AdminDeliverySlip\">
                                <a href=\"/admin9671czlrok7qbdn2pre/index.php/sell/orders/delivery-slips/?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" class=\"link\"> Delivery Slips
                                </a>
                             ' | raw }}{{ ' </li>

                                                                                  
                              
                                                            
                              <li class=\"link-leveltwo\" data-submenu=\"8\" id=\"subtab-AdminCarts\">
                                <a href=\"http://localhost:8100/admin9671czlrok7qbdn2pre/index.php?controller=AdminCarts&amp;token=0d5ca87f77c7df188a030908f654599d\" class=\"link\"> Shopping Carts
                                </a>
                              </li>

                                                                              </ul>
                                        </li>
                                              
                  
                                                      
                  
                  <li class=\"link-levelone has_submenu\" data-submenu=\"9\" id=\"subtab-AdminCatalog\">
                    <a href=\"/admin9671czlrok7qbdn2pre/index.php/sell/catalog/products?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" class=\"link\">
                      <i class=\"material-icons mi-store\">store</i>
                      <span>
                      Catalog
                      </span>
                                                    <i class=\"material-icons sub-tabs-arrow\">
                                                                    keyboard_arrow_down
                                                            </i>
                                            </a>
                                              <ul id=\"collapse-9\" class=\"submenu panel-collapse\">
                                                      
                              
                                                            
                              <li class=\"link-leveltwo\" data-submenu=\"10\" id=\"subtab-AdminProducts\">
                                <a href=\"/admin9671czlrok7qbdn2pre/index.php/sell/catalog/products?_token=ATlXt2ftKxRdgFMQMrDdQICfh26' | raw }}{{ 'VHYibwaRp4FSAwr4\" class=\"link\"> Products
                                </a>
                              </li>

                                                                                  
                              
                                                            
                              <li class=\"link-leveltwo\" data-submenu=\"11\" id=\"subtab-AdminCategories\">
                                <a href=\"/admin9671czlrok7qbdn2pre/index.php/sell/catalog/categories?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" class=\"link\"> Categories
                                </a>
                              </li>

                                                                                  
                              
                                                            
                              <li class=\"link-leveltwo\" data-submenu=\"12\" id=\"subtab-AdminTracking\">
                                <a href=\"/admin9671czlrok7qbdn2pre/index.php/sell/catalog/monitoring/?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" class=\"link\"> Monitoring
                                </a>
                              </li>

                                                                                  
                              
                                                            
                              <li class=\"link-leveltwo\" data-submenu=\"13\" id=\"subtab-AdminParentAttributesGroups\">
                                <a href=\"http://localhost:8100/admin9671czlrok7qbdn2pre/index.php?controller=AdminAttributesGroups&amp;token=2daf160f8f4bb2ac08f6e6efd1c42be5\" class=\"link\"> Attributes &amp; Features
                                </a>
                              </li>

                                                                                  
                              
                                                            
                              <li class=\"link-leveltwo\" data-submenu=\"16' | raw }}{{ '\" id=\"subtab-AdminParentManufacturers\">
                                <a href=\"/admin9671czlrok7qbdn2pre/index.php/sell/catalog/brands/?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" class=\"link\"> Brands &amp; Suppliers
                                </a>
                              </li>

                                                                                  
                              
                                                            
                              <li class=\"link-leveltwo\" data-submenu=\"19\" id=\"subtab-AdminAttachments\">
                                <a href=\"/admin9671czlrok7qbdn2pre/index.php/sell/attachments/?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" class=\"link\"> Files
                                </a>
                              </li>

                                                                                  
                              
                                                            
                              <li class=\"link-leveltwo\" data-submenu=\"20\" id=\"subtab-AdminParentCartRules\">
                                <a href=\"http://localhost:8100/admin9671czlrok7qbdn2pre/index.php?controller=AdminCartRules&amp;token=35066e1fdaa2d26975dea7c5521c7d78\" class=\"link\"> Discounts
                                </a>
                              </li>

                                                                                  
                              
                                                            
                              <li class=\"link-leveltwo\" data-submenu=\"23\" id=\"subtab-AdminStockManagement\">
                                <a href=\"/admin9671czlrok7qbdn2pre/index.php/sell/stocks/?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" class=\"link\"> Stock
                                </a>
                              </li>

                                                                              </ul>
                           ' | raw }}{{ '             </li>
                                              
                  
                                                      
                  
                  <li class=\"link-levelone has_submenu\" data-submenu=\"24\" id=\"subtab-AdminParentCustomer\">
                    <a href=\"/admin9671czlrok7qbdn2pre/index.php/sell/customers/?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" class=\"link\">
                      <i class=\"material-icons mi-account_circle\">account_circle</i>
                      <span>
                      Customers
                      </span>
                                                    <i class=\"material-icons sub-tabs-arrow\">
                                                                    keyboard_arrow_down
                                                            </i>
                                            </a>
                                              <ul id=\"collapse-24\" class=\"submenu panel-collapse\">
                                                      
                              
                                                            
                              <li class=\"link-leveltwo\" data-submenu=\"25\" id=\"subtab-AdminCustomers\">
                                <a href=\"/admin9671czlrok7qbdn2pre/index.php/sell/customers/?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" class=\"link\"> Customers
                                </a>
                              </li>

                                                                                  
                              
                                                            
                              <li class=\"link-leveltwo\" data-submenu=\"26\" id=\"subtab-AdminAddresses\">
                                <a href=\"/admin9671czlrok7qbdn2pre/index.php/sell/addresses/?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" class=\"link\"> Addresses
                                </a>
                              </li>

    ' | raw }}{{ '                                                                                                                                </ul>
                                        </li>
                                              
                  
                                                      
                  
                  <li class=\"link-levelone has_submenu\" data-submenu=\"28\" id=\"subtab-AdminParentCustomerThreads\">
                    <a href=\"http://localhost:8100/admin9671czlrok7qbdn2pre/index.php?controller=AdminCustomerThreads&amp;token=8e4778b624cce2f3558ef1de6fda99ac\" class=\"link\">
                      <i class=\"material-icons mi-chat\">chat</i>
                      <span>
                      Customer Service
                      </span>
                                                    <i class=\"material-icons sub-tabs-arrow\">
                                                                    keyboard_arrow_down
                                                            </i>
                                            </a>
                                              <ul id=\"collapse-28\" class=\"submenu panel-collapse\">
                                                      
                              
                                                            
                              <li class=\"link-leveltwo\" data-submenu=\"29\" id=\"subtab-AdminCustomerThreads\">
                                <a href=\"http://localhost:8100/admin9671czlrok7qbdn2pre/index.php?controller=AdminCustomerThreads&amp;token=8e4778b624cce2f3558ef1de6fda99ac\" class=\"link\"> Customer Service
                                </a>
                              </li>

                                                                                  
                              
                                                            
                              <li class=\"link-leveltwo\" data-submenu=\"30\" id=\"subtab-AdminOrderMessage\">
                  ' | raw }}{{ '              <a href=\"/admin9671czlrok7qbdn2pre/index.php/sell/customer-service/order-messages/?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" class=\"link\"> Order Messages
                                </a>
                              </li>

                                                                                  
                              
                                                            
                              <li class=\"link-leveltwo\" data-submenu=\"31\" id=\"subtab-AdminReturn\">
                                <a href=\"http://localhost:8100/admin9671czlrok7qbdn2pre/index.php?controller=AdminReturn&amp;token=86bf8977be3c26ea2502c871c132f94c\" class=\"link\"> Merchandise Returns
                                </a>
                              </li>

                                                                              </ul>
                                        </li>
                                              
                  
                                                      
                  
                  <li class=\"link-levelone\" data-submenu=\"32\" id=\"subtab-AdminStats\">
                    <a href=\"http://localhost:8100/admin9671czlrok7qbdn2pre/index.php?controller=AdminStats&amp;token=03bd53e5ad9da963a1b60c654a2e1fd8\" class=\"link\">
                      <i class=\"material-icons mi-assessment\">assessment</i>
                      <span>
                      Stats
                      </span>
                                                    <i class=\"material-icons sub-tabs-arrow\">
                                                                    keyboard_arrow_down
                                                            </i>
                                            </a>
                                        </li>
                              
          
                      
                                          
                    
          
            <li class=\"category-t' | raw }}{{ 'itle\" data-submenu=\"37\" id=\"tab-IMPROVE\">
                <span class=\"title\">Improve</span>
            </li>

                              
                  
                                                      
                  
                  <li class=\"link-levelone has_submenu\" data-submenu=\"38\" id=\"subtab-AdminParentModulesSf\">
                    <a href=\"/admin9671czlrok7qbdn2pre/index.php/improve/modules/manage?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" class=\"link\">
                      <i class=\"material-icons mi-extension\">extension</i>
                      <span>
                      Modules
                      </span>
                                                    <i class=\"material-icons sub-tabs-arrow\">
                                                                    keyboard_arrow_down
                                                            </i>
                                            </a>
                                              <ul id=\"collapse-38\" class=\"submenu panel-collapse\">
                                                      
                              
                                                            
                              <li class=\"link-leveltwo\" data-submenu=\"39\" id=\"subtab-AdminModulesSf\">
                                <a href=\"/admin9671czlrok7qbdn2pre/index.php/improve/modules/manage?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" class=\"link\"> Module Manager
                                </a>
                              </li>

                                                                                                                                    </ul>
                                        </li>
                                              
                  
                                                      
                  
                  <li class=\"link-levelone has_submenu\" data-submenu=\"43\" id=\"subtab-AdminParentThemes\">
          ' | raw }}{{ '          <a href=\"/admin9671czlrok7qbdn2pre/index.php/improve/design/themes/?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" class=\"link\">
                      <i class=\"material-icons mi-desktop_mac\">desktop_mac</i>
                      <span>
                      Design
                      </span>
                                                    <i class=\"material-icons sub-tabs-arrow\">
                                                                    keyboard_arrow_down
                                                            </i>
                                            </a>
                                              <ul id=\"collapse-43\" class=\"submenu panel-collapse\">
                                                      
                              
                                                            
                              <li class=\"link-leveltwo\" data-submenu=\"128\" id=\"subtab-AdminThemesParent\">
                                <a href=\"/admin9671czlrok7qbdn2pre/index.php/improve/design/themes/?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" class=\"link\"> Theme &amp; Logo
                                </a>
                              </li>

                                                                                  
                              
                                                            
                              <li class=\"link-leveltwo\" data-submenu=\"45\" id=\"subtab-AdminParentMailTheme\">
                                <a href=\"/admin9671czlrok7qbdn2pre/index.php/improve/design/mail_theme/?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" class=\"link\"> Email Theme
                                </a>
                              </li>

                                                                                  
                              
                                                            
                              <li class=\"link-leveltwo\" data-submenu=\"' | raw }}{{ '47\" id=\"subtab-AdminCmsContent\">
                                <a href=\"/admin9671czlrok7qbdn2pre/index.php/improve/design/cms-pages/?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" class=\"link\"> Pages
                                </a>
                              </li>

                                                                                  
                              
                                                            
                              <li class=\"link-leveltwo\" data-submenu=\"48\" id=\"subtab-AdminModulesPositions\">
                                <a href=\"/admin9671czlrok7qbdn2pre/index.php/improve/design/modules/positions/?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" class=\"link\"> Positions
                                </a>
                              </li>

                                                                                  
                              
                                                            
                              <li class=\"link-leveltwo\" data-submenu=\"49\" id=\"subtab-AdminImages\">
                                <a href=\"http://localhost:8100/admin9671czlrok7qbdn2pre/index.php?controller=AdminImages&amp;token=8dba008ad901fccb7eeabfd3d6b26c53\" class=\"link\"> Image Settings
                                </a>
                              </li>

                                                                                  
                              
                                                            
                              <li class=\"link-leveltwo\" data-submenu=\"118\" id=\"subtab-AdminLinkWidget\">
                                <a href=\"/admin9671czlrok7qbdn2pre/index.php/modules/link-widget/list?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" class=\"link\"> Link List
                                </a>
                              </li>

                                                                              </ul>
                ' | raw }}{{ '                        </li>
                                              
                  
                                                      
                  
                  <li class=\"link-levelone has_submenu\" data-submenu=\"50\" id=\"subtab-AdminParentShipping\">
                    <a href=\"http://localhost:8100/admin9671czlrok7qbdn2pre/index.php?controller=AdminCarriers&amp;token=46efc14f5d6fb6399f66aa3658416d22\" class=\"link\">
                      <i class=\"material-icons mi-local_shipping\">local_shipping</i>
                      <span>
                      Shipping
                      </span>
                                                    <i class=\"material-icons sub-tabs-arrow\">
                                                                    keyboard_arrow_down
                                                            </i>
                                            </a>
                                              <ul id=\"collapse-50\" class=\"submenu panel-collapse\">
                                                      
                              
                                                            
                              <li class=\"link-leveltwo\" data-submenu=\"51\" id=\"subtab-AdminCarriers\">
                                <a href=\"http://localhost:8100/admin9671czlrok7qbdn2pre/index.php?controller=AdminCarriers&amp;token=46efc14f5d6fb6399f66aa3658416d22\" class=\"link\"> Carriers
                                </a>
                              </li>

                                                                                  
                              
                                                            
                              <li class=\"link-leveltwo\" data-submenu=\"52\" id=\"subtab-AdminShipping\">
                                <a href=\"/admin9671czlrok7qbdn2pre/index.php/improve/shipping/preferences/?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" class=\"link\"> Preferences
           ' | raw }}{{ '                     </a>
                              </li>

                                                                              </ul>
                                        </li>
                                              
                  
                                                      
                  
                  <li class=\"link-levelone has_submenu\" data-submenu=\"53\" id=\"subtab-AdminParentPayment\">
                    <a href=\"/admin9671czlrok7qbdn2pre/index.php/improve/payment/payment_methods?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" class=\"link\">
                      <i class=\"material-icons mi-payment\">payment</i>
                      <span>
                      Payment
                      </span>
                                                    <i class=\"material-icons sub-tabs-arrow\">
                                                                    keyboard_arrow_down
                                                            </i>
                                            </a>
                                              <ul id=\"collapse-53\" class=\"submenu panel-collapse\">
                                                      
                              
                                                            
                              <li class=\"link-leveltwo\" data-submenu=\"54\" id=\"subtab-AdminPayment\">
                                <a href=\"/admin9671czlrok7qbdn2pre/index.php/improve/payment/payment_methods?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" class=\"link\"> Payment Methods
                                </a>
                              </li>

                                                                                  
                              
                                                            
                              <li class=\"link-leveltwo\" data-submenu=\"55\" id=\"subtab-AdminPaymentPreferences\">
                                <a href=\"/adm' | raw }}{{ 'in9671czlrok7qbdn2pre/index.php/improve/payment/preferences?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" class=\"link\"> Preferences
                                </a>
                              </li>

                                                                              </ul>
                                        </li>
                                              
                  
                                                      
                  
                  <li class=\"link-levelone has_submenu\" data-submenu=\"56\" id=\"subtab-AdminInternational\">
                    <a href=\"/admin9671czlrok7qbdn2pre/index.php/improve/international/localization/?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" class=\"link\">
                      <i class=\"material-icons mi-language\">language</i>
                      <span>
                      International
                      </span>
                                                    <i class=\"material-icons sub-tabs-arrow\">
                                                                    keyboard_arrow_down
                                                            </i>
                                            </a>
                                              <ul id=\"collapse-56\" class=\"submenu panel-collapse\">
                                                      
                              
                                                            
                              <li class=\"link-leveltwo\" data-submenu=\"57\" id=\"subtab-AdminParentLocalization\">
                                <a href=\"/admin9671czlrok7qbdn2pre/index.php/improve/international/localization/?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" class=\"link\"> Localization
                                </a>
                              </li>

                                                                                  
                              
                                            ' | raw }}{{ '                
                              <li class=\"link-leveltwo\" data-submenu=\"62\" id=\"subtab-AdminParentCountries\">
                                <a href=\"/admin9671czlrok7qbdn2pre/index.php/improve/international/zones/?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" class=\"link\"> Locations
                                </a>
                              </li>

                                                                                  
                              
                                                            
                              <li class=\"link-leveltwo\" data-submenu=\"66\" id=\"subtab-AdminParentTaxes\">
                                <a href=\"/admin9671czlrok7qbdn2pre/index.php/improve/international/taxes/?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" class=\"link\"> Taxes
                                </a>
                              </li>

                                                                                  
                              
                                                            
                              <li class=\"link-leveltwo\" data-submenu=\"69\" id=\"subtab-AdminTranslations\">
                                <a href=\"/admin9671czlrok7qbdn2pre/index.php/improve/international/translations/settings?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" class=\"link\"> Translations
                                </a>
                              </li>

                                                                              </ul>
                                        </li>
                              
          
                      
                                          
                    
          
            <li class=\"category-title link-active\" data-submenu=\"70\" id=\"tab-CONFIGURE\">
                <span class=\"title\">Configure</span>
            </li>

                              
                  
                                                     ' | raw }}{{ ' 
                  
                  <li class=\"link-levelone has_submenu\" data-submenu=\"71\" id=\"subtab-ShopParameters\">
                    <a href=\"/admin9671czlrok7qbdn2pre/index.php/configure/shop/preferences/preferences?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" class=\"link\">
                      <i class=\"material-icons mi-settings\">settings</i>
                      <span>
                      Shop Parameters
                      </span>
                                                    <i class=\"material-icons sub-tabs-arrow\">
                                                                    keyboard_arrow_down
                                                            </i>
                                            </a>
                                              <ul id=\"collapse-71\" class=\"submenu panel-collapse\">
                                                      
                              
                                                            
                              <li class=\"link-leveltwo\" data-submenu=\"72\" id=\"subtab-AdminParentPreferences\">
                                <a href=\"/admin9671czlrok7qbdn2pre/index.php/configure/shop/preferences/preferences?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" class=\"link\"> General
                                </a>
                              </li>

                                                                                  
                              
                                                            
                              <li class=\"link-leveltwo\" data-submenu=\"75\" id=\"subtab-AdminParentOrderPreferences\">
                                <a href=\"/admin9671czlrok7qbdn2pre/index.php/configure/shop/order-preferences/?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" class=\"link\"> Order Settings
                                </a>
                              </li>

                                                                 ' | raw }}{{ '                 
                              
                                                            
                              <li class=\"link-leveltwo\" data-submenu=\"78\" id=\"subtab-AdminPPreferences\">
                                <a href=\"/admin9671czlrok7qbdn2pre/index.php/configure/shop/product-preferences/?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" class=\"link\"> Product Settings
                                </a>
                              </li>

                                                                                  
                              
                                                            
                              <li class=\"link-leveltwo\" data-submenu=\"79\" id=\"subtab-AdminParentCustomerPreferences\">
                                <a href=\"/admin9671czlrok7qbdn2pre/index.php/configure/shop/customer-preferences/?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" class=\"link\"> Customer Settings
                                </a>
                              </li>

                                                                                  
                              
                                                            
                              <li class=\"link-leveltwo\" data-submenu=\"83\" id=\"subtab-AdminParentStores\">
                                <a href=\"/admin9671czlrok7qbdn2pre/index.php/configure/shop/contacts/?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" class=\"link\"> Contact
                                </a>
                              </li>

                                                                                  
                              
                                                            
                              <li class=\"link-leveltwo\" data-submenu=\"86\" id=\"subtab-AdminParentMeta\">
                                <a href=\"/admin9671czlrok7qbdn2pre/index.php/configure/shop/seo-urls/?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibw' | raw }}{{ 'aRp4FSAwr4\" class=\"link\"> Traffic &amp; SEO
                                </a>
                              </li>

                                                                                  
                              
                                                            
                              <li class=\"link-leveltwo\" data-submenu=\"89\" id=\"subtab-AdminParentSearchConf\">
                                <a href=\"http://localhost:8100/admin9671czlrok7qbdn2pre/index.php?controller=AdminSearchConf&amp;token=de51787e0572085c273958439c1079e9\" class=\"link\"> Search
                                </a>
                              </li>

                                                                              </ul>
                                        </li>
                                              
                  
                                                      
                                                          
                  <li class=\"link-levelone has_submenu link-active open ul-open\" data-submenu=\"92\" id=\"subtab-AdminAdvancedParameters\">
                    <a href=\"/admin9671czlrok7qbdn2pre/index.php/configure/advanced/system-information/?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" class=\"link\">
                      <i class=\"material-icons mi-settings_applications\">settings_applications</i>
                      <span>
                      Advanced Parameters
                      </span>
                                                    <i class=\"material-icons sub-tabs-arrow\">
                                                                    keyboard_arrow_up
                                                            </i>
                                            </a>
                                              <ul id=\"collapse-92\" class=\"submenu panel-collapse\">
                                                      
                              
                                       ' | raw }}{{ '                     
                              <li class=\"link-leveltwo\" data-submenu=\"93\" id=\"subtab-AdminInformation\">
                                <a href=\"/admin9671czlrok7qbdn2pre/index.php/configure/advanced/system-information/?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" class=\"link\"> Information
                                </a>
                              </li>

                                                                                  
                              
                                                            
                              <li class=\"link-leveltwo\" data-submenu=\"94\" id=\"subtab-AdminPerformance\">
                                <a href=\"/admin9671czlrok7qbdn2pre/index.php/configure/advanced/performance/?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" class=\"link\"> Performance
                                </a>
                              </li>

                                                                                  
                              
                                                            
                              <li class=\"link-leveltwo\" data-submenu=\"95\" id=\"subtab-AdminAdminPreferences\">
                                <a href=\"/admin9671czlrok7qbdn2pre/index.php/configure/advanced/administration/?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" class=\"link\"> Administration
                                </a>
                              </li>

                                                                                  
                              
                                                            
                              <li class=\"link-leveltwo\" data-submenu=\"96\" id=\"subtab-AdminEmails\">
                                <a href=\"/admin9671czlrok7qbdn2pre/index.php/configure/advanced/emails/?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" class=\"link\"> E-mail
                                </a>
                           ' | raw }}{{ '   </li>

                                                                                  
                              
                                                            
                              <li class=\"link-leveltwo\" data-submenu=\"97\" id=\"subtab-AdminImport\">
                                <a href=\"/admin9671czlrok7qbdn2pre/index.php/configure/advanced/import/?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" class=\"link\"> Import
                                </a>
                              </li>

                                                                                  
                              
                                                            
                              <li class=\"link-leveltwo link-active\" data-submenu=\"98\" id=\"subtab-AdminParentEmployees\">
                                <a href=\"/admin9671czlrok7qbdn2pre/index.php/configure/advanced/employees/?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" class=\"link\"> Team
                                </a>
                              </li>

                                                                                  
                              
                                                            
                              <li class=\"link-leveltwo\" data-submenu=\"102\" id=\"subtab-AdminParentRequestSql\">
                                <a href=\"/admin9671czlrok7qbdn2pre/index.php/configure/advanced/sql-requests/?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" class=\"link\"> Database
                                </a>
                              </li>

                                                                                  
                              
                                                            
                              <li class=\"link-leveltwo\" data-submenu=\"105\" id=\"subtab-AdminLogs\">
                                <a href=\"/admin9671czlrok7qbdn2pre/index.php/configure/advanced/logs/' | raw }}{{ '?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" class=\"link\"> Logs
                                </a>
                              </li>

                                                                                  
                              
                                                            
                              <li class=\"link-leveltwo\" data-submenu=\"106\" id=\"subtab-AdminWebservice\">
                                <a href=\"/admin9671czlrok7qbdn2pre/index.php/configure/advanced/webservice-keys/?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" class=\"link\"> Webservice
                                </a>
                              </li>

                                                                                                                                                                                                                                                    
                              
                                                            
                              <li class=\"link-leveltwo\" data-submenu=\"110\" id=\"subtab-AdminFeatureFlag\">
                                <a href=\"/admin9671czlrok7qbdn2pre/index.php/configure/advanced/feature-flags/?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" class=\"link\"> New &amp; Experimental Features
                                </a>
                              </li>

                                                                                  
                              
                                                            
                              <li class=\"link-leveltwo\" data-submenu=\"111\" id=\"subtab-AdminParentSecurity\">
                                <a href=\"/admin9671czlrok7qbdn2pre/index.php/configure/advanced/security/?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" class=\"link\"> Security
                                </a>
                              </li>

                                                ' | raw }}{{ '                              </ul>
                                        </li>
                              
          
                  </ul>
  </div>
  
</nav>


<div class=\"header-toolbar d-print-none\">
    
  <div class=\"container-fluid\">

    
      <nav aria-label=\"Breadcrumb\">
        <ol class=\"breadcrumb\">
                      <li class=\"breadcrumb-item\">Team</li>
          
                      <li class=\"breadcrumb-item active\">
              <a href=\"/admin9671czlrok7qbdn2pre/index.php/configure/advanced/employees/?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" aria-current=\"page\">Employees</a>
            </li>
                  </ol>
      </nav>
    

    <div class=\"title-row\">
      
          <h1 class=\"title\">
            Employees          </h1>
      

      
        <div class=\"toolbar-icons\">
          <div class=\"wrapper\">
            
                                                          <a
                  class=\"btn btn-primary pointer\"                  id=\"page-header-desc-configuration-add\"
                  href=\"/admin9671czlrok7qbdn2pre/index.php/configure/advanced/employees/new?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\"                  title=\"Add new employee\"                                  >
                  <i class=\"material-icons\">add_circle_outline</i>                  Add new employee
                </a>
                                      
            
                              <a class=\"btn btn-outline-secondary btn-help btn-sidebar\" href=\"#\"
                   title=\"Help\"
                   data-toggle=\"sidebar\"
                   data-target=\"#right-sidebar\"
                   data-url=\"/admin9671czlrok7qbdn2pre/index.php/common/sidebar/https%253A%252F%252Fhelp.prestashop-project.org%252Fen%252Fdoc%252FAdminEmployees%253Fversion%253D8.2.0%2526country%253Den/Help?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\"
                   id=\"product_form_open_help\"
                >
         ' | raw }}{{ '         Help
                </a>
                                    </div>
        </div>

      
    </div>
  </div>

  
      <div class=\"page-head-tabs\" id=\"head_tabs\">
      <ul class=\"nav nav-pills\">
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              <li class=\"nav-item\">
                    <a href=\"/admin9671czlrok7qbdn2pre/index.php/configure/advanced/employees/?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" id=\"subtab-AdminEmployees\" class=\"nav-link tab active current\" data-submenu=\"99\">
                      Employees
                      <span class=\"notification-container\">
                        <span class=\"notification-counter\"></span>
                      </' | raw }}{{ 'span>
                    </a>
                  </li>
                                                                <li class=\"nav-item\">
                    <a href=\"/admin9671czlrok7qbdn2pre/index.php/configure/advanced/profiles/?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\" id=\"subtab-AdminProfiles\" class=\"nav-link tab \" data-submenu=\"100\">
                      Profiles
                      <span class=\"notification-container\">
                        <span class=\"notification-counter\"></span>
                      </span>
                    </a>
                  </li>
                                                                <li class=\"nav-item\">
                    <a href=\"http://localhost:8100/admin9671czlrok7qbdn2pre/index.php?controller=AdminAccess&token=b35d39da47f1ffe7898cdbf37b35ab90\" id=\"subtab-AdminAccess\" class=\"nav-link tab \" data-submenu=\"101\">
                      Permissions
                      <span class=\"notification-container\">
                        <span class=\"notification-counter\"></span>
                      </span>
                    </a>
                  </li>
                                                                                                                                                                                                                                                        </ul>
    </div>
  
  <div class=\"btn-floating\">
    <button class=\"btn btn-primary collapsed\" data-toggle=\"collapse\" data-target=\".btn-floating-container\" aria-expanded=\"false\">
      <i class=\"material-icons\">add</i>
    </button>
    <div class=\"btn-floating-container collapse\">
      <div class=\"btn-floating-menu\">
        
                              <a
              class=\"btn btn-floating-item   pointer\"              id=\"page-header-desc-floating-configuration-add\"
              href=\"/admin9671czlrok7qbdn2pre/index.php/configure/advanced/employees/new?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\"' | raw }}{{ '              title=\"Add new employee\"            >
              Add new employee
              <i class=\"material-icons\">add_circle_outline</i>            </a>
                  
                              <a class=\"btn btn-floating-item btn-help btn-sidebar\" href=\"#\"
               title=\"Help\"
               data-toggle=\"sidebar\"
               data-target=\"#right-sidebar\"
               data-url=\"/admin9671czlrok7qbdn2pre/index.php/common/sidebar/https%253A%252F%252Fhelp.prestashop-project.org%252Fen%252Fdoc%252FAdminEmployees%253Fversion%253D8.2.0%2526country%253Den/Help?_token=ATlXt2ftKxRdgFMQMrDdQICfh26VHYibwaRp4FSAwr4\"
            >
              Help
            </a>
                        </div>
    </div>
  </div>
  
</div>

<div id=\"main-div\">
          
      <div class=\"content-div  with-tabs\">

        

                                                        
        <div id=\"ajax_confirmation\" class=\"alert alert-success\" style=\"display: none;\"></div>
<div id=\"content-message-box\"></div>


  ' | raw }}{% block content_header %}{% endblock %}{% block content %}{% endblock %}{% block content_footer %}{% endblock %}{% block sidebar_right %}{% endblock %}{{ '

        

      </div>
    </div>

  <div id=\"non-responsive\" class=\"js-non-responsive\">
  <h1>Oh no!</h1>
  <p class=\"mt-3\">
    The mobile version of this page is not available yet.
  </p>
  <p class=\"mt-2\">
    Please use a desktop computer to access this page, until is adapted to mobile.
  </p>
  <p class=\"mt-2\">
    Thank you.
  </p>
  <a href=\"http://localhost:8100/admin9671czlrok7qbdn2pre/index.php?controller=AdminDashboard&amp;token=b95bec1cb57a4c3a2694b03b4e02f5fb\" class=\"btn btn-primary py-1 mt-3\">
    <i class=\"material-icons rtl-flip\">arrow_back</i>
    Back
  </a>
</div>
  <div class=\"mobile-layer\"></div>

      <div id=\"footer\" class=\"bootstrap\">
    
</div>
  

      <div class=\"bootstrap\">
      
    </div>
  
' | raw }}{% block javascripts %}{% endblock %}{% block extra_javascripts %}{% endblock %}{% block translate_javascripts %}{% endblock %}</body>{{ '
</html>' | raw }}", "__string_template__f9172b8d71aa35948d90359afab7219b", "");
    }
}
