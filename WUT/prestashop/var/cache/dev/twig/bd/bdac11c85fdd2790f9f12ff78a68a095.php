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

/* @PrestaShop/Admin/Sell/Customer/Blocks/delete_modal.html.twig */
class __TwigTemplate_f1f6db4bad8931dc5761d9b90328b6a7 extends Template
{
    private $source;
    private $macros = [];

    public function __construct(Environment $env)
    {
        parent::__construct($env);

        $this->source = $this->getSourceContext();

        $this->parent = false;

        $this->blocks = [
        ];
    }

    protected function doDisplay(array $context, array $blocks = [])
    {
        $macros = $this->macros;
        $__internal_5a27a8ba21ca79b61932376b2fa922d2 = $this->extensions["Symfony\\Bundle\\WebProfilerBundle\\Twig\\WebProfilerExtension"];
        $__internal_5a27a8ba21ca79b61932376b2fa922d2->enter($__internal_5a27a8ba21ca79b61932376b2fa922d2_prof = new \Twig\Profiler\Profile($this->getTemplateName(), "template", "@PrestaShop/Admin/Sell/Customer/Blocks/delete_modal.html.twig"));

        $__internal_6f47bbe9983af81f1e7450e9a3e3768f = $this->extensions["Symfony\\Bridge\\Twig\\Extension\\ProfilerExtension"];
        $__internal_6f47bbe9983af81f1e7450e9a3e3768f->enter($__internal_6f47bbe9983af81f1e7450e9a3e3768f_prof = new \Twig\Profiler\Profile($this->getTemplateName(), "template", "@PrestaShop/Admin/Sell/Customer/Blocks/delete_modal.html.twig"));

        // line 25
        echo "
";
        // line 26
        $this->loadTemplate("@PrestaShop/Admin/Sell/Customer/Blocks/delete_modal.html.twig", "@PrestaShop/Admin/Sell/Customer/Blocks/delete_modal.html.twig", 26, "1976291344")->display(twig_array_merge($context, ["id" => (twig_get_attribute($this->env, $this->source,         // line 27
(isset($context["grid"]) || array_key_exists("grid", $context) ? $context["grid"] : (function () { throw new RuntimeError('Variable "grid" does not exist.', 27, $this->source); })()), "id", [], "any", false, false, false, 27) . "_grid_delete_customers_modal"), "title" => $this->extensions['Symfony\Bridge\Twig\Extension\TranslationExtension']->trans("How do you want to delete the selected customers?", [], "Admin.Orderscustomers.Notification"), "closable" => true, "closeLabel" => $this->extensions['Symfony\Bridge\Twig\Extension\TranslationExtension']->trans("Cancel", [], "Admin.Actions"), "actions" => [0 => ["type" => "button", "label" => $this->extensions['Symfony\Bridge\Twig\Extension\TranslationExtension']->trans("Delete", [], "Admin.Actions"), "class" => "btn btn-danger btn-lg js-submit-delete-customers"]]]));
        
        $__internal_5a27a8ba21ca79b61932376b2fa922d2->leave($__internal_5a27a8ba21ca79b61932376b2fa922d2_prof);

        
        $__internal_6f47bbe9983af81f1e7450e9a3e3768f->leave($__internal_6f47bbe9983af81f1e7450e9a3e3768f_prof);

    }

    public function getTemplateName()
    {
        return "@PrestaShop/Admin/Sell/Customer/Blocks/delete_modal.html.twig";
    }

    public function isTraitable()
    {
        return false;
    }

    public function getDebugInfo()
    {
        return array (  47 => 27,  46 => 26,  43 => 25,);
    }

    public function getSourceContext()
    {
        return new Source("{#**
 * Copyright since 2007 PrestaShop SA and Contributors
 * PrestaShop is an International Registered Trademark & Property of PrestaShop SA
 *
 * NOTICE OF LICENSE
 *
 * This source file is subject to the Open Software License (OSL 3.0)
 * that is bundled with this package in the file LICENSE.md.
 * It is also available through the world-wide-web at this URL:
 * https://opensource.org/licenses/OSL-3.0
 * If you did not receive a copy of the license and are unable to
 * obtain it through the world-wide-web, please send an email
 * to license@prestashop.com so we can send you a copy immediately.
 *
 * DISCLAIMER
 *
 * Do not edit or add to this file if you wish to upgrade PrestaShop to newer
 * versions in the future. If you wish to customize PrestaShop for your
 * needs please refer to https://devdocs.prestashop.com/ for more information.
 *
 * @author    PrestaShop SA and Contributors <contact@prestashop.com>
 * @copyright Since 2007 PrestaShop SA and Contributors
 * @license   https://opensource.org/licenses/OSL-3.0 Open Software License (OSL 3.0)
 *#}

{% embed '@PrestaShop/Admin/Helpers/bootstrap_popup.html.twig' with {
  'id': grid.id ~ '_grid_delete_customers_modal',
  'title': \"How do you want to delete the selected customers?\"|trans({}, 'Admin.Orderscustomers.Notification'),
  'closable': true,
  'closeLabel': \"Cancel\"|trans({}, 'Admin.Actions'),
  'actions': [{
    'type': 'button',
    'label': \"Delete\"|trans({}, 'Admin.Actions'),
    'class': 'btn btn-danger btn-lg js-submit-delete-customers',
  }],
} %}
  {% block content %}
    <div class=\"modal-body\">
      <p>{{ 'There are two ways of deleting a customer. Please choose your preferred method.'|trans({}, 'Admin.Orderscustomers.Notification') }}</p>
      {% block delete_customers_form %}
        {{ form_start(deleteCustomersForm, {'action': path('admin_customers_index'), 'method': 'post'}) }}

        <div class=\"form-group mb-0\">
          {{ form_widget(deleteCustomersForm.delete_method) }}
        </div>

        <div class=\"d-none\">
          {{ form_widget(deleteCustomersForm.customers_to_delete) }}
        </div>

        {{ form_end(deleteCustomersForm) }}
      {% endblock %}
    </div>
  {% endblock %}
{% endembed %}
", "@PrestaShop/Admin/Sell/Customer/Blocks/delete_modal.html.twig", "/var/www/html/src/PrestaShopBundle/Resources/views/Admin/Sell/Customer/Blocks/delete_modal.html.twig");
    }
}


/* @PrestaShop/Admin/Sell/Customer/Blocks/delete_modal.html.twig */
class __TwigTemplate_f1f6db4bad8931dc5761d9b90328b6a7___1976291344 extends Template
{
    private $source;
    private $macros = [];

    public function __construct(Environment $env)
    {
        parent::__construct($env);

        $this->source = $this->getSourceContext();

        $this->blocks = [
            'content' => [$this, 'block_content'],
            'delete_customers_form' => [$this, 'block_delete_customers_form'],
        ];
    }

    protected function doGetParent(array $context)
    {
        // line 26
        return "@PrestaShop/Admin/Helpers/bootstrap_popup.html.twig";
    }

    protected function doDisplay(array $context, array $blocks = [])
    {
        $macros = $this->macros;
        $__internal_5a27a8ba21ca79b61932376b2fa922d2 = $this->extensions["Symfony\\Bundle\\WebProfilerBundle\\Twig\\WebProfilerExtension"];
        $__internal_5a27a8ba21ca79b61932376b2fa922d2->enter($__internal_5a27a8ba21ca79b61932376b2fa922d2_prof = new \Twig\Profiler\Profile($this->getTemplateName(), "template", "@PrestaShop/Admin/Sell/Customer/Blocks/delete_modal.html.twig"));

        $__internal_6f47bbe9983af81f1e7450e9a3e3768f = $this->extensions["Symfony\\Bridge\\Twig\\Extension\\ProfilerExtension"];
        $__internal_6f47bbe9983af81f1e7450e9a3e3768f->enter($__internal_6f47bbe9983af81f1e7450e9a3e3768f_prof = new \Twig\Profiler\Profile($this->getTemplateName(), "template", "@PrestaShop/Admin/Sell/Customer/Blocks/delete_modal.html.twig"));

        $this->parent = $this->loadTemplate("@PrestaShop/Admin/Helpers/bootstrap_popup.html.twig", "@PrestaShop/Admin/Sell/Customer/Blocks/delete_modal.html.twig", 26);
        $this->parent->display($context, array_merge($this->blocks, $blocks));
        
        $__internal_5a27a8ba21ca79b61932376b2fa922d2->leave($__internal_5a27a8ba21ca79b61932376b2fa922d2_prof);

        
        $__internal_6f47bbe9983af81f1e7450e9a3e3768f->leave($__internal_6f47bbe9983af81f1e7450e9a3e3768f_prof);

    }

    // line 37
    public function block_content($context, array $blocks = [])
    {
        $macros = $this->macros;
        $__internal_5a27a8ba21ca79b61932376b2fa922d2 = $this->extensions["Symfony\\Bundle\\WebProfilerBundle\\Twig\\WebProfilerExtension"];
        $__internal_5a27a8ba21ca79b61932376b2fa922d2->enter($__internal_5a27a8ba21ca79b61932376b2fa922d2_prof = new \Twig\Profiler\Profile($this->getTemplateName(), "block", "content"));

        $__internal_6f47bbe9983af81f1e7450e9a3e3768f = $this->extensions["Symfony\\Bridge\\Twig\\Extension\\ProfilerExtension"];
        $__internal_6f47bbe9983af81f1e7450e9a3e3768f->enter($__internal_6f47bbe9983af81f1e7450e9a3e3768f_prof = new \Twig\Profiler\Profile($this->getTemplateName(), "block", "content"));

        // line 38
        echo "    <div class=\"modal-body\">
      <p>";
        // line 39
        echo twig_escape_filter($this->env, $this->extensions['Symfony\Bridge\Twig\Extension\TranslationExtension']->trans("There are two ways of deleting a customer. Please choose your preferred method.", [], "Admin.Orderscustomers.Notification"), "html", null, true);
        echo "</p>
      ";
        // line 40
        $this->displayBlock('delete_customers_form', $context, $blocks);
        // line 53
        echo "    </div>
  ";
        
        $__internal_6f47bbe9983af81f1e7450e9a3e3768f->leave($__internal_6f47bbe9983af81f1e7450e9a3e3768f_prof);

        
        $__internal_5a27a8ba21ca79b61932376b2fa922d2->leave($__internal_5a27a8ba21ca79b61932376b2fa922d2_prof);

    }

    // line 40
    public function block_delete_customers_form($context, array $blocks = [])
    {
        $macros = $this->macros;
        $__internal_5a27a8ba21ca79b61932376b2fa922d2 = $this->extensions["Symfony\\Bundle\\WebProfilerBundle\\Twig\\WebProfilerExtension"];
        $__internal_5a27a8ba21ca79b61932376b2fa922d2->enter($__internal_5a27a8ba21ca79b61932376b2fa922d2_prof = new \Twig\Profiler\Profile($this->getTemplateName(), "block", "delete_customers_form"));

        $__internal_6f47bbe9983af81f1e7450e9a3e3768f = $this->extensions["Symfony\\Bridge\\Twig\\Extension\\ProfilerExtension"];
        $__internal_6f47bbe9983af81f1e7450e9a3e3768f->enter($__internal_6f47bbe9983af81f1e7450e9a3e3768f_prof = new \Twig\Profiler\Profile($this->getTemplateName(), "block", "delete_customers_form"));

        // line 41
        echo "        ";
        echo         $this->env->getRuntime('Symfony\Component\Form\FormRenderer')->renderBlock((isset($context["deleteCustomersForm"]) || array_key_exists("deleteCustomersForm", $context) ? $context["deleteCustomersForm"] : (function () { throw new RuntimeError('Variable "deleteCustomersForm" does not exist.', 41, $this->source); })()), 'form_start', ["action" => $this->extensions['Symfony\Bridge\Twig\Extension\RoutingExtension']->getPath("admin_customers_index"), "method" => "post"]);
        echo "

        <div class=\"form-group mb-0\">
          ";
        // line 44
        echo $this->env->getRuntime('Symfony\Component\Form\FormRenderer')->searchAndRenderBlock(twig_get_attribute($this->env, $this->source, (isset($context["deleteCustomersForm"]) || array_key_exists("deleteCustomersForm", $context) ? $context["deleteCustomersForm"] : (function () { throw new RuntimeError('Variable "deleteCustomersForm" does not exist.', 44, $this->source); })()), "delete_method", [], "any", false, false, false, 44), 'widget');
        echo "
        </div>

        <div class=\"d-none\">
          ";
        // line 48
        echo $this->env->getRuntime('Symfony\Component\Form\FormRenderer')->searchAndRenderBlock(twig_get_attribute($this->env, $this->source, (isset($context["deleteCustomersForm"]) || array_key_exists("deleteCustomersForm", $context) ? $context["deleteCustomersForm"] : (function () { throw new RuntimeError('Variable "deleteCustomersForm" does not exist.', 48, $this->source); })()), "customers_to_delete", [], "any", false, false, false, 48), 'widget');
        echo "
        </div>

        ";
        // line 51
        echo         $this->env->getRuntime('Symfony\Component\Form\FormRenderer')->renderBlock((isset($context["deleteCustomersForm"]) || array_key_exists("deleteCustomersForm", $context) ? $context["deleteCustomersForm"] : (function () { throw new RuntimeError('Variable "deleteCustomersForm" does not exist.', 51, $this->source); })()), 'form_end');
        echo "
      ";
        
        $__internal_6f47bbe9983af81f1e7450e9a3e3768f->leave($__internal_6f47bbe9983af81f1e7450e9a3e3768f_prof);

        
        $__internal_5a27a8ba21ca79b61932376b2fa922d2->leave($__internal_5a27a8ba21ca79b61932376b2fa922d2_prof);

    }

    public function getTemplateName()
    {
        return "@PrestaShop/Admin/Sell/Customer/Blocks/delete_modal.html.twig";
    }

    public function isTraitable()
    {
        return false;
    }

    public function getDebugInfo()
    {
        return array (  237 => 51,  231 => 48,  224 => 44,  217 => 41,  207 => 40,  196 => 53,  194 => 40,  190 => 39,  187 => 38,  177 => 37,  154 => 26,  47 => 27,  46 => 26,  43 => 25,);
    }

    public function getSourceContext()
    {
        return new Source("{#**
 * Copyright since 2007 PrestaShop SA and Contributors
 * PrestaShop is an International Registered Trademark & Property of PrestaShop SA
 *
 * NOTICE OF LICENSE
 *
 * This source file is subject to the Open Software License (OSL 3.0)
 * that is bundled with this package in the file LICENSE.md.
 * It is also available through the world-wide-web at this URL:
 * https://opensource.org/licenses/OSL-3.0
 * If you did not receive a copy of the license and are unable to
 * obtain it through the world-wide-web, please send an email
 * to license@prestashop.com so we can send you a copy immediately.
 *
 * DISCLAIMER
 *
 * Do not edit or add to this file if you wish to upgrade PrestaShop to newer
 * versions in the future. If you wish to customize PrestaShop for your
 * needs please refer to https://devdocs.prestashop.com/ for more information.
 *
 * @author    PrestaShop SA and Contributors <contact@prestashop.com>
 * @copyright Since 2007 PrestaShop SA and Contributors
 * @license   https://opensource.org/licenses/OSL-3.0 Open Software License (OSL 3.0)
 *#}

{% embed '@PrestaShop/Admin/Helpers/bootstrap_popup.html.twig' with {
  'id': grid.id ~ '_grid_delete_customers_modal',
  'title': \"How do you want to delete the selected customers?\"|trans({}, 'Admin.Orderscustomers.Notification'),
  'closable': true,
  'closeLabel': \"Cancel\"|trans({}, 'Admin.Actions'),
  'actions': [{
    'type': 'button',
    'label': \"Delete\"|trans({}, 'Admin.Actions'),
    'class': 'btn btn-danger btn-lg js-submit-delete-customers',
  }],
} %}
  {% block content %}
    <div class=\"modal-body\">
      <p>{{ 'There are two ways of deleting a customer. Please choose your preferred method.'|trans({}, 'Admin.Orderscustomers.Notification') }}</p>
      {% block delete_customers_form %}
        {{ form_start(deleteCustomersForm, {'action': path('admin_customers_index'), 'method': 'post'}) }}

        <div class=\"form-group mb-0\">
          {{ form_widget(deleteCustomersForm.delete_method) }}
        </div>

        <div class=\"d-none\">
          {{ form_widget(deleteCustomersForm.customers_to_delete) }}
        </div>

        {{ form_end(deleteCustomersForm) }}
      {% endblock %}
    </div>
  {% endblock %}
{% endembed %}
", "@PrestaShop/Admin/Sell/Customer/Blocks/delete_modal.html.twig", "/var/www/html/src/PrestaShopBundle/Resources/views/Admin/Sell/Customer/Blocks/delete_modal.html.twig");
    }
}
