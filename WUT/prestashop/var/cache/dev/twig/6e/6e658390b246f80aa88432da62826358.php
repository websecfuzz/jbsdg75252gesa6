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

/* @PrestaShop/Admin/Configure/AdvancedParameters/Security/index.html.twig */
class __TwigTemplate_4421c741aa799dd3fd70b9d790b43f0d extends Template
{
    private $source;
    private $macros = [];

    public function __construct(Environment $env)
    {
        parent::__construct($env);

        $this->source = $this->getSourceContext();

        $this->blocks = [
            'content' => [$this, 'block_content'],
            'administration_form_general' => [$this, 'block_administration_form_general'],
            'administration_form_password_policy' => [$this, 'block_administration_form_password_policy'],
        ];
    }

    protected function doGetParent(array $context)
    {
        // line 26
        return "@PrestaShop/Admin/layout.html.twig";
    }

    protected function doDisplay(array $context, array $blocks = [])
    {
        $macros = $this->macros;
        $__internal_5a27a8ba21ca79b61932376b2fa922d2 = $this->extensions["Symfony\\Bundle\\WebProfilerBundle\\Twig\\WebProfilerExtension"];
        $__internal_5a27a8ba21ca79b61932376b2fa922d2->enter($__internal_5a27a8ba21ca79b61932376b2fa922d2_prof = new \Twig\Profiler\Profile($this->getTemplateName(), "template", "@PrestaShop/Admin/Configure/AdvancedParameters/Security/index.html.twig"));

        $__internal_6f47bbe9983af81f1e7450e9a3e3768f = $this->extensions["Symfony\\Bridge\\Twig\\Extension\\ProfilerExtension"];
        $__internal_6f47bbe9983af81f1e7450e9a3e3768f->enter($__internal_6f47bbe9983af81f1e7450e9a3e3768f_prof = new \Twig\Profiler\Profile($this->getTemplateName(), "template", "@PrestaShop/Admin/Configure/AdvancedParameters/Security/index.html.twig"));

        // line 28
        $macros["ps"] = $this->macros["ps"] = $this->loadTemplate("@PrestaShop/Admin/macros.html.twig", "@PrestaShop/Admin/Configure/AdvancedParameters/Security/index.html.twig", 28)->unwrap();
        // line 26
        $this->parent = $this->loadTemplate("@PrestaShop/Admin/layout.html.twig", "@PrestaShop/Admin/Configure/AdvancedParameters/Security/index.html.twig", 26);
        $this->parent->display($context, array_merge($this->blocks, $blocks));
        
        $__internal_5a27a8ba21ca79b61932376b2fa922d2->leave($__internal_5a27a8ba21ca79b61932376b2fa922d2_prof);

        
        $__internal_6f47bbe9983af81f1e7450e9a3e3768f->leave($__internal_6f47bbe9983af81f1e7450e9a3e3768f_prof);

    }

    // line 30
    public function block_content($context, array $blocks = [])
    {
        $macros = $this->macros;
        $__internal_5a27a8ba21ca79b61932376b2fa922d2 = $this->extensions["Symfony\\Bundle\\WebProfilerBundle\\Twig\\WebProfilerExtension"];
        $__internal_5a27a8ba21ca79b61932376b2fa922d2->enter($__internal_5a27a8ba21ca79b61932376b2fa922d2_prof = new \Twig\Profiler\Profile($this->getTemplateName(), "block", "content"));

        $__internal_6f47bbe9983af81f1e7450e9a3e3768f = $this->extensions["Symfony\\Bridge\\Twig\\Extension\\ProfilerExtension"];
        $__internal_6f47bbe9983af81f1e7450e9a3e3768f->enter($__internal_6f47bbe9983af81f1e7450e9a3e3768f_prof = new \Twig\Profiler\Profile($this->getTemplateName(), "block", "content"));

        // line 31
        echo "  ";
        $this->loadTemplate("@PrestaShop/Admin/Common/multistore-infotip.html.twig", "@PrestaShop/Admin/Configure/AdvancedParameters/Security/index.html.twig", 31)->display($context);
        // line 32
        echo "
  ";
        // line 33
        echo         $this->env->getRuntime('Symfony\Component\Form\FormRenderer')->renderBlock((isset($context["generalForm"]) || array_key_exists("generalForm", $context) ? $context["generalForm"] : (function () { throw new RuntimeError('Variable "generalForm" does not exist.', 33, $this->source); })()), 'form_start', ["attr" => ["class" => "form"], "action" => $this->extensions['Symfony\Bridge\Twig\Extension\RoutingExtension']->getPath("admin_security_general_save")]);
        echo "
    ";
        // line 34
        $this->displayBlock('administration_form_general', $context, $blocks);
        // line 52
        echo "  ";
        echo         $this->env->getRuntime('Symfony\Component\Form\FormRenderer')->renderBlock((isset($context["generalForm"]) || array_key_exists("generalForm", $context) ? $context["generalForm"] : (function () { throw new RuntimeError('Variable "generalForm" does not exist.', 52, $this->source); })()), 'form_end');
        echo "

  ";
        // line 54
        echo         $this->env->getRuntime('Symfony\Component\Form\FormRenderer')->renderBlock((isset($context["passwordPolicyForm"]) || array_key_exists("passwordPolicyForm", $context) ? $context["passwordPolicyForm"] : (function () { throw new RuntimeError('Variable "passwordPolicyForm" does not exist.', 54, $this->source); })()), 'form_start', ["attr" => ["class" => "form"], "action" => $this->extensions['Symfony\Bridge\Twig\Extension\RoutingExtension']->getPath("admin_security_password_policy_save")]);
        echo "
    ";
        // line 55
        $this->displayBlock('administration_form_password_policy', $context, $blocks);
        // line 89
        echo "  ";
        echo         $this->env->getRuntime('Symfony\Component\Form\FormRenderer')->renderBlock((isset($context["passwordPolicyForm"]) || array_key_exists("passwordPolicyForm", $context) ? $context["passwordPolicyForm"] : (function () { throw new RuntimeError('Variable "passwordPolicyForm" does not exist.', 89, $this->source); })()), 'form_end');
        echo "
";
        
        $__internal_6f47bbe9983af81f1e7450e9a3e3768f->leave($__internal_6f47bbe9983af81f1e7450e9a3e3768f_prof);

        
        $__internal_5a27a8ba21ca79b61932376b2fa922d2->leave($__internal_5a27a8ba21ca79b61932376b2fa922d2_prof);

    }

    // line 34
    public function block_administration_form_general($context, array $blocks = [])
    {
        $macros = $this->macros;
        $__internal_5a27a8ba21ca79b61932376b2fa922d2 = $this->extensions["Symfony\\Bundle\\WebProfilerBundle\\Twig\\WebProfilerExtension"];
        $__internal_5a27a8ba21ca79b61932376b2fa922d2->enter($__internal_5a27a8ba21ca79b61932376b2fa922d2_prof = new \Twig\Profiler\Profile($this->getTemplateName(), "block", "administration_form_general"));

        $__internal_6f47bbe9983af81f1e7450e9a3e3768f = $this->extensions["Symfony\\Bridge\\Twig\\Extension\\ProfilerExtension"];
        $__internal_6f47bbe9983af81f1e7450e9a3e3768f->enter($__internal_6f47bbe9983af81f1e7450e9a3e3768f_prof = new \Twig\Profiler\Profile($this->getTemplateName(), "block", "administration_form_general"));

        // line 35
        echo "      <div class=\"card\" id=\"configuration_fieldset_general\">
        <h3 class=\"card-header\">
          <i class=\"material-icons\">settings</i> ";
        // line 37
        echo twig_escape_filter($this->env, $this->extensions['Symfony\Bridge\Twig\Extension\TranslationExtension']->trans("General", [], "Admin.Global"), "html", null, true);
        echo "
        </h3>
        <div class=\"card-body\">
          <div class=\"form-wrapper\">
            ";
        // line 41
        echo $this->env->getRuntime('Symfony\Component\Form\FormRenderer')->searchAndRenderBlock((isset($context["generalForm"]) || array_key_exists("generalForm", $context) ? $context["generalForm"] : (function () { throw new RuntimeError('Variable "generalForm" does not exist.', 41, $this->source); })()), 'widget');
        echo "
            ";
        // line 42
        echo $this->env->getRuntime('Symfony\Component\Form\FormRenderer')->searchAndRenderBlock((isset($context["generalForm"]) || array_key_exists("generalForm", $context) ? $context["generalForm"] : (function () { throw new RuntimeError('Variable "generalForm" does not exist.', 42, $this->source); })()), 'rest');
        echo "
          </div>
        </div>
        <div class=\"card-footer\">
          <div class=\"d-flex justify-content-end\">
            <button type=\"submit\" class=\"btn btn-primary\">";
        // line 47
        echo twig_escape_filter($this->env, $this->extensions['Symfony\Bridge\Twig\Extension\TranslationExtension']->trans("Save", [], "Admin.Actions"), "html", null, true);
        echo "</button>
          </div>
        </div>
      </div>
    ";
        
        $__internal_6f47bbe9983af81f1e7450e9a3e3768f->leave($__internal_6f47bbe9983af81f1e7450e9a3e3768f_prof);

        
        $__internal_5a27a8ba21ca79b61932376b2fa922d2->leave($__internal_5a27a8ba21ca79b61932376b2fa922d2_prof);

    }

    // line 55
    public function block_administration_form_password_policy($context, array $blocks = [])
    {
        $macros = $this->macros;
        $__internal_5a27a8ba21ca79b61932376b2fa922d2 = $this->extensions["Symfony\\Bundle\\WebProfilerBundle\\Twig\\WebProfilerExtension"];
        $__internal_5a27a8ba21ca79b61932376b2fa922d2->enter($__internal_5a27a8ba21ca79b61932376b2fa922d2_prof = new \Twig\Profiler\Profile($this->getTemplateName(), "block", "administration_form_password_policy"));

        $__internal_6f47bbe9983af81f1e7450e9a3e3768f = $this->extensions["Symfony\\Bridge\\Twig\\Extension\\ProfilerExtension"];
        $__internal_6f47bbe9983af81f1e7450e9a3e3768f->enter($__internal_6f47bbe9983af81f1e7450e9a3e3768f_prof = new \Twig\Profiler\Profile($this->getTemplateName(), "block", "administration_form_password_policy"));

        // line 56
        echo "      <div class=\"card\" id=\"configuration_fieldset_password_policy\">
        <h3 class=\"card-header\">
          <i class=\"material-icons\">settings</i> ";
        // line 58
        echo twig_escape_filter($this->env, $this->extensions['Symfony\Bridge\Twig\Extension\TranslationExtension']->trans("Password policy", [], "Admin.Advparameters.Feature"), "html", null, true);
        echo "
        </h3>
        <div class=\"card-body\">
          <div class=\"form-wrapper\">
            <div class=\"form-group row\">
              ";
        // line 63
        echo $this->env->getRuntime('Symfony\Component\Form\FormRenderer')->searchAndRenderBlock(twig_get_attribute($this->env, $this->source, (isset($context["passwordPolicyForm"]) || array_key_exists("passwordPolicyForm", $context) ? $context["passwordPolicyForm"] : (function () { throw new RuntimeError('Variable "passwordPolicyForm" does not exist.', 63, $this->source); })()), "minimum_score", [], "any", false, false, false, 63), 'label');
        echo "
              <div class=\"col-sm\">
                ";
        // line 65
        echo $this->env->getRuntime('Symfony\Component\Form\FormRenderer')->searchAndRenderBlock(twig_get_attribute($this->env, $this->source, (isset($context["passwordPolicyForm"]) || array_key_exists("passwordPolicyForm", $context) ? $context["passwordPolicyForm"] : (function () { throw new RuntimeError('Variable "passwordPolicyForm" does not exist.', 65, $this->source); })()), "minimum_score", [], "any", false, false, false, 65), 'widget');
        echo "
                <small class=\"form-text\">
                  ";
        // line 67
        echo twig_escape_filter($this->env, $this->extensions['Symfony\Bridge\Twig\Extension\TranslationExtension']->trans("Scores are integers from 0 to 4.", [], "Admin.Advparameters.Help"), "html", null, true);
        echo "
                  <ol id=\"help-password-score\">
                    <li>";
        // line 69
        echo twig_escape_filter($this->env, $this->extensions['Symfony\Bridge\Twig\Extension\TranslationExtension']->trans("0 means the password is extremely easy to guess (within 10^3 guesses). Dictionary words like \"password\" or \"mother\" score 0.", [], "Admin.Advparameters.Feature"), "html", null, true);
        echo "</li>
                    <li>";
        // line 70
        echo twig_escape_filter($this->env, $this->extensions['Symfony\Bridge\Twig\Extension\TranslationExtension']->trans("1 is still very easy to guess (guesses less than 10^6). An extra character on a dictionary word can score 1.", [], "Admin.Advparameters.Feature"), "html", null, true);
        echo "</li>
                    <li>";
        // line 71
        echo twig_escape_filter($this->env, $this->extensions['Symfony\Bridge\Twig\Extension\TranslationExtension']->trans("2 is pretty easy to guess (guesses less than 10^8). It provides some protection from unthrottled online attacks.", [], "Admin.Advparameters.Feature"), "html", null, true);
        echo "</li>
                    <li>";
        // line 72
        echo twig_escape_filter($this->env, $this->extensions['Symfony\Bridge\Twig\Extension\TranslationExtension']->trans("3 is safely unguessable (guesses less than 10^10). It offers moderate protection from offline slow-hash scenario.", [], "Admin.Advparameters.Feature"), "html", null, true);
        echo "</li>
                    <li>";
        // line 73
        echo twig_escape_filter($this->env, $this->extensions['Symfony\Bridge\Twig\Extension\TranslationExtension']->trans("4 is very unguessable (guesses greater than or equal to 10^10) and provides strong protection from offline slow-hash scenario.", [], "Admin.Advparameters.Feature"), "html", null, true);
        echo "</li>
                  </ol>
                </small>
              </div>
            </div>
          ";
        // line 78
        echo $this->env->getRuntime('Symfony\Component\Form\FormRenderer')->searchAndRenderBlock((isset($context["passwordPolicyForm"]) || array_key_exists("passwordPolicyForm", $context) ? $context["passwordPolicyForm"] : (function () { throw new RuntimeError('Variable "passwordPolicyForm" does not exist.', 78, $this->source); })()), 'widget');
        echo "
          ";
        // line 79
        echo $this->env->getRuntime('Symfony\Component\Form\FormRenderer')->searchAndRenderBlock((isset($context["passwordPolicyForm"]) || array_key_exists("passwordPolicyForm", $context) ? $context["passwordPolicyForm"] : (function () { throw new RuntimeError('Variable "passwordPolicyForm" does not exist.', 79, $this->source); })()), 'rest');
        echo "
          </div>
        </div>
        <div class=\"card-footer\">
          <div class=\"d-flex justify-content-end\">
            <button type=\"submit\" class=\"btn btn-primary\">";
        // line 84
        echo twig_escape_filter($this->env, $this->extensions['Symfony\Bridge\Twig\Extension\TranslationExtension']->trans("Save", [], "Admin.Actions"), "html", null, true);
        echo "</button>
          </div>
        </div>
      </div>
    ";
        
        $__internal_6f47bbe9983af81f1e7450e9a3e3768f->leave($__internal_6f47bbe9983af81f1e7450e9a3e3768f_prof);

        
        $__internal_5a27a8ba21ca79b61932376b2fa922d2->leave($__internal_5a27a8ba21ca79b61932376b2fa922d2_prof);

    }

    public function getTemplateName()
    {
        return "@PrestaShop/Admin/Configure/AdvancedParameters/Security/index.html.twig";
    }

    public function isTraitable()
    {
        return false;
    }

    public function getDebugInfo()
    {
        return array (  231 => 84,  223 => 79,  219 => 78,  211 => 73,  207 => 72,  203 => 71,  199 => 70,  195 => 69,  190 => 67,  185 => 65,  180 => 63,  172 => 58,  168 => 56,  158 => 55,  143 => 47,  135 => 42,  131 => 41,  124 => 37,  120 => 35,  110 => 34,  97 => 89,  95 => 55,  91 => 54,  85 => 52,  83 => 34,  79 => 33,  76 => 32,  73 => 31,  63 => 30,  52 => 26,  50 => 28,  37 => 26,);
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

{% extends '@PrestaShop/Admin/layout.html.twig' %}
{% trans_default_domain \"Admin.Advparameters.Feature\" %}
{% import '@PrestaShop/Admin/macros.html.twig' as ps %}

{% block content %}
  {% include '@PrestaShop/Admin/Common/multistore-infotip.html.twig' %}

  {{ form_start(generalForm, {attr : {class: 'form'}, action: path('admin_security_general_save') }) }}
    {% block administration_form_general %}
      <div class=\"card\" id=\"configuration_fieldset_general\">
        <h3 class=\"card-header\">
          <i class=\"material-icons\">settings</i> {{ 'General'|trans({}, 'Admin.Global') }}
        </h3>
        <div class=\"card-body\">
          <div class=\"form-wrapper\">
            {{ form_widget(generalForm) }}
            {{ form_rest(generalForm) }}
          </div>
        </div>
        <div class=\"card-footer\">
          <div class=\"d-flex justify-content-end\">
            <button type=\"submit\" class=\"btn btn-primary\">{{ 'Save'|trans({}, 'Admin.Actions') }}</button>
          </div>
        </div>
      </div>
    {% endblock %}
  {{ form_end(generalForm) }}

  {{ form_start(passwordPolicyForm, {attr : {class: 'form'}, action: path('admin_security_password_policy_save') }) }}
    {% block administration_form_password_policy %}
      <div class=\"card\" id=\"configuration_fieldset_password_policy\">
        <h3 class=\"card-header\">
          <i class=\"material-icons\">settings</i> {{ 'Password policy'|trans({}, 'Admin.Advparameters.Feature') }}
        </h3>
        <div class=\"card-body\">
          <div class=\"form-wrapper\">
            <div class=\"form-group row\">
              {{ form_label(passwordPolicyForm.minimum_score) }}
              <div class=\"col-sm\">
                {{ form_widget(passwordPolicyForm.minimum_score) }}
                <small class=\"form-text\">
                  {{ 'Scores are integers from 0 to 4.'|trans({}, 'Admin.Advparameters.Help') }}
                  <ol id=\"help-password-score\">
                    <li>{{ '0 means the password is extremely easy to guess (within 10^3 guesses). Dictionary words like \"password\" or \"mother\" score 0.'|trans({}, 'Admin.Advparameters.Feature') }}</li>
                    <li>{{ '1 is still very easy to guess (guesses less than 10^6). An extra character on a dictionary word can score 1.'|trans({}, 'Admin.Advparameters.Feature') }}</li>
                    <li>{{ '2 is pretty easy to guess (guesses less than 10^8). It provides some protection from unthrottled online attacks.'|trans({}, 'Admin.Advparameters.Feature') }}</li>
                    <li>{{ '3 is safely unguessable (guesses less than 10^10). It offers moderate protection from offline slow-hash scenario.'|trans({}, 'Admin.Advparameters.Feature') }}</li>
                    <li>{{ '4 is very unguessable (guesses greater than or equal to 10^10) and provides strong protection from offline slow-hash scenario.'|trans({}, 'Admin.Advparameters.Feature') }}</li>
                  </ol>
                </small>
              </div>
            </div>
          {{ form_widget(passwordPolicyForm) }}
          {{ form_rest(passwordPolicyForm) }}
          </div>
        </div>
        <div class=\"card-footer\">
          <div class=\"d-flex justify-content-end\">
            <button type=\"submit\" class=\"btn btn-primary\">{{ 'Save'|trans({}, 'Admin.Actions') }}</button>
          </div>
        </div>
      </div>
    {% endblock %}
  {{ form_end(passwordPolicyForm) }}
{% endblock %}
", "@PrestaShop/Admin/Configure/AdvancedParameters/Security/index.html.twig", "/var/www/html/src/PrestaShopBundle/Resources/views/Admin/Configure/AdvancedParameters/Security/index.html.twig");
    }
}
