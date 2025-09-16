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

/* @PrestaShop/Admin/Sell/Customer/Blocks/Index/required_fields.html.twig */
class __TwigTemplate_7cb25b398d957aa965125ab34e15a7df extends Template
{
    private $source;
    private $macros = [];

    public function __construct(Environment $env)
    {
        parent::__construct($env);

        $this->source = $this->getSourceContext();

        $this->parent = false;

        $this->blocks = [
            'customer_required_fields_form' => [$this, 'block_customer_required_fields_form'],
        ];
    }

    protected function doDisplay(array $context, array $blocks = [])
    {
        $macros = $this->macros;
        $__internal_5a27a8ba21ca79b61932376b2fa922d2 = $this->extensions["Symfony\\Bundle\\WebProfilerBundle\\Twig\\WebProfilerExtension"];
        $__internal_5a27a8ba21ca79b61932376b2fa922d2->enter($__internal_5a27a8ba21ca79b61932376b2fa922d2_prof = new \Twig\Profiler\Profile($this->getTemplateName(), "template", "@PrestaShop/Admin/Sell/Customer/Blocks/Index/required_fields.html.twig"));

        $__internal_6f47bbe9983af81f1e7450e9a3e3768f = $this->extensions["Symfony\\Bridge\\Twig\\Extension\\ProfilerExtension"];
        $__internal_6f47bbe9983af81f1e7450e9a3e3768f->enter($__internal_6f47bbe9983af81f1e7450e9a3e3768f_prof = new \Twig\Profiler\Profile($this->getTemplateName(), "template", "@PrestaShop/Admin/Sell/Customer/Blocks/Index/required_fields.html.twig"));

        // line 25
        $this->env->getRuntime("Symfony\\Component\\Form\\FormRenderer")->setTheme((isset($context["customerRequiredFieldsForm"]) || array_key_exists("customerRequiredFieldsForm", $context) ? $context["customerRequiredFieldsForm"] : (function () { throw new RuntimeError('Variable "customerRequiredFieldsForm" does not exist.', 25, $this->source); })()), [0 => "@PrestaShop/Admin/TwigTemplateForm/prestashop_ui_kit.html.twig"], true);
        // line 26
        echo "
<div class=\"collapse\" id=\"customerRequiredFieldsContainer\">
  ";
        // line 28
        $this->displayBlock('customer_required_fields_form', $context, $blocks);
        // line 62
        echo "</div>
";
        
        $__internal_5a27a8ba21ca79b61932376b2fa922d2->leave($__internal_5a27a8ba21ca79b61932376b2fa922d2_prof);

        
        $__internal_6f47bbe9983af81f1e7450e9a3e3768f->leave($__internal_6f47bbe9983af81f1e7450e9a3e3768f_prof);

    }

    // line 28
    public function block_customer_required_fields_form($context, array $blocks = [])
    {
        $macros = $this->macros;
        $__internal_5a27a8ba21ca79b61932376b2fa922d2 = $this->extensions["Symfony\\Bundle\\WebProfilerBundle\\Twig\\WebProfilerExtension"];
        $__internal_5a27a8ba21ca79b61932376b2fa922d2->enter($__internal_5a27a8ba21ca79b61932376b2fa922d2_prof = new \Twig\Profiler\Profile($this->getTemplateName(), "block", "customer_required_fields_form"));

        $__internal_6f47bbe9983af81f1e7450e9a3e3768f = $this->extensions["Symfony\\Bridge\\Twig\\Extension\\ProfilerExtension"];
        $__internal_6f47bbe9983af81f1e7450e9a3e3768f->enter($__internal_6f47bbe9983af81f1e7450e9a3e3768f_prof = new \Twig\Profiler\Profile($this->getTemplateName(), "block", "customer_required_fields_form"));

        // line 29
        echo "    ";
        echo         $this->env->getRuntime('Symfony\Component\Form\FormRenderer')->renderBlock((isset($context["customerRequiredFieldsForm"]) || array_key_exists("customerRequiredFieldsForm", $context) ? $context["customerRequiredFieldsForm"] : (function () { throw new RuntimeError('Variable "customerRequiredFieldsForm" does not exist.', 29, $this->source); })()), 'form_start', ["action" => $this->extensions['Symfony\Bridge\Twig\Extension\RoutingExtension']->getPath("admin_customers_set_required_fields")]);
        echo "
    <div class=\"card\" >
      <h3 class=\"card-header\">
        ";
        // line 32
        echo twig_escape_filter($this->env, $this->extensions['Symfony\Bridge\Twig\Extension\TranslationExtension']->trans("Required fields", [], "Admin.Orderscustomers.Feature"), "html", null, true);
        echo "
      </h3>
      <div class=\"card-body\">
        <div class=\"alert alert-info\" role=\"alert\">
          <div class=\"alert-text\">
            <p>";
        // line 37
        echo twig_escape_filter($this->env, $this->extensions['Symfony\Bridge\Twig\Extension\TranslationExtension']->trans("Select the fields you would like to be required for this section.", [], "Admin.Orderscustomers.Help"), "html", null, true);
        echo "</p>
            <p>";
        // line 38
        echo twig_escape_filter($this->env, $this->extensions['Symfony\Bridge\Twig\Extension\TranslationExtension']->trans("Please make sure you are complying with the opt-in legislation applicable in your country.", [], "Admin.Orderscustomers.Help"), "html", null, true);
        echo "</p>
          </div>
        </div>
        <div class=\"alert alert-danger d-none\" role=\"alert\" id=\"customerRequiredFieldsAlertMessageOptin\">
          <div class=\"alert-text\">
            <p>";
        // line 43
        echo $this->extensions['Symfony\Bridge\Twig\Extension\TranslationExtension']->trans("[1]Make[/1] sure you enable partner offers in the [2]Shop Parameters > Customer Settings[/2] section of the back office before requiring them. Otherwise, new customers won't be able to create an account and [1]proceed[/1] to checkout.", ["[1]" => "<strong>", "[/1]" => "</strong>", "[2]" => (("<a href=\"" . $this->extensions['Symfony\Bridge\Twig\Extension\RoutingExtension']->getPath("admin_customer_preferences")) . "\">"), "[/2]" => "</a>"], "Admin.Orderscustomers.Help");
        // line 48
        echo "</p>
          </div>
        </div>

        ";
        // line 52
        echo $this->env->getRuntime('Symfony\Component\Form\FormRenderer')->searchAndRenderBlock(twig_get_attribute($this->env, $this->source, (isset($context["customerRequiredFieldsForm"]) || array_key_exists("customerRequiredFieldsForm", $context) ? $context["customerRequiredFieldsForm"] : (function () { throw new RuntimeError('Variable "customerRequiredFieldsForm" does not exist.', 52, $this->source); })()), "required_fields", [], "any", false, false, false, 52), 'widget');
        echo "
      </div>
      <div class=\"card-footer\">
        <div class=\"d-flex justify-content-end\">
          <button class=\"btn btn-primary\">";
        // line 56
        echo twig_escape_filter($this->env, $this->extensions['Symfony\Bridge\Twig\Extension\TranslationExtension']->trans("Save", [], "Admin.Actions"), "html", null, true);
        echo "</button>
        </div>
      </div>
    </div>
    ";
        // line 60
        echo         $this->env->getRuntime('Symfony\Component\Form\FormRenderer')->renderBlock((isset($context["customerRequiredFieldsForm"]) || array_key_exists("customerRequiredFieldsForm", $context) ? $context["customerRequiredFieldsForm"] : (function () { throw new RuntimeError('Variable "customerRequiredFieldsForm" does not exist.', 60, $this->source); })()), 'form_end');
        echo "
  ";
        
        $__internal_6f47bbe9983af81f1e7450e9a3e3768f->leave($__internal_6f47bbe9983af81f1e7450e9a3e3768f_prof);

        
        $__internal_5a27a8ba21ca79b61932376b2fa922d2->leave($__internal_5a27a8ba21ca79b61932376b2fa922d2_prof);

    }

    public function getTemplateName()
    {
        return "@PrestaShop/Admin/Sell/Customer/Blocks/Index/required_fields.html.twig";
    }

    public function isTraitable()
    {
        return false;
    }

    public function getDebugInfo()
    {
        return array (  122 => 60,  115 => 56,  108 => 52,  102 => 48,  100 => 43,  92 => 38,  88 => 37,  80 => 32,  73 => 29,  63 => 28,  52 => 62,  50 => 28,  46 => 26,  44 => 25,);
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
{% form_theme customerRequiredFieldsForm '@PrestaShop/Admin/TwigTemplateForm/prestashop_ui_kit.html.twig' %}

<div class=\"collapse\" id=\"customerRequiredFieldsContainer\">
  {% block customer_required_fields_form %}
    {{ form_start(customerRequiredFieldsForm, {'action': path('admin_customers_set_required_fields')}) }}
    <div class=\"card\" >
      <h3 class=\"card-header\">
        {{ 'Required fields'|trans({}, 'Admin.Orderscustomers.Feature') }}
      </h3>
      <div class=\"card-body\">
        <div class=\"alert alert-info\" role=\"alert\">
          <div class=\"alert-text\">
            <p>{{ 'Select the fields you would like to be required for this section.'|trans({}, 'Admin.Orderscustomers.Help') }}</p>
            <p>{{ 'Please make sure you are complying with the opt-in legislation applicable in your country.'|trans({}, 'Admin.Orderscustomers.Help') }}</p>
          </div>
        </div>
        <div class=\"alert alert-danger d-none\" role=\"alert\" id=\"customerRequiredFieldsAlertMessageOptin\">
          <div class=\"alert-text\">
            <p>{{ '[1]Make[/1] sure you enable partner offers in the [2]Shop Parameters > Customer Settings[/2] section of the back office before requiring them. Otherwise, new customers won\\'t be able to create an account and [1]proceed[/1] to checkout.'|trans({
                '[1]': '<strong>',
                '[/1]': '</strong>',
                '[2]': '<a href=\"' ~ path('admin_customer_preferences') ~ '\">',
                '[/2]': '</a>',
              }, 'Admin.Orderscustomers.Help')|raw }}</p>
          </div>
        </div>

        {{ form_widget(customerRequiredFieldsForm.required_fields) }}
      </div>
      <div class=\"card-footer\">
        <div class=\"d-flex justify-content-end\">
          <button class=\"btn btn-primary\">{{ 'Save'|trans({}, 'Admin.Actions') }}</button>
        </div>
      </div>
    </div>
    {{ form_end(customerRequiredFieldsForm) }}
  {% endblock %}
</div>
", "@PrestaShop/Admin/Sell/Customer/Blocks/Index/required_fields.html.twig", "/var/www/html/src/PrestaShopBundle/Resources/views/Admin/Sell/Customer/Blocks/Index/required_fields.html.twig");
    }
}
