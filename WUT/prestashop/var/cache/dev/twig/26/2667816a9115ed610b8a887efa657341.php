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

/* @PrestaShop/Admin/Common/Grid/Columns/Content/severity_level.html.twig */
class __TwigTemplate_3b3fed432afe167311feaa846311b5e3 extends Template
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
        $__internal_5a27a8ba21ca79b61932376b2fa922d2->enter($__internal_5a27a8ba21ca79b61932376b2fa922d2_prof = new \Twig\Profiler\Profile($this->getTemplateName(), "template", "@PrestaShop/Admin/Common/Grid/Columns/Content/severity_level.html.twig"));

        $__internal_6f47bbe9983af81f1e7450e9a3e3768f = $this->extensions["Symfony\\Bridge\\Twig\\Extension\\ProfilerExtension"];
        $__internal_6f47bbe9983af81f1e7450e9a3e3768f->enter($__internal_6f47bbe9983af81f1e7450e9a3e3768f_prof = new \Twig\Profiler\Profile($this->getTemplateName(), "template", "@PrestaShop/Admin/Common/Grid/Columns/Content/severity_level.html.twig"));

        // line 25
        echo "
";
        // line 26
        $context["severity"] = twig_get_attribute($this->env, $this->source, (isset($context["record"]) || array_key_exists("record", $context) ? $context["record"] : (function () { throw new RuntimeError('Variable "record" does not exist.', 26, $this->source); })()), "severity", [], "any", false, false, false, 26);
        // line 27
        $context["withMessage"] = twig_get_attribute($this->env, $this->source, twig_get_attribute($this->env, $this->source, (isset($context["column"]) || array_key_exists("column", $context) ? $context["column"] : (function () { throw new RuntimeError('Variable "column" does not exist.', 27, $this->source); })()), "options", [], "any", false, false, false, 27), "with_message", [], "any", false, false, false, 27);
        // line 28
        echo "
";
        // line 29
        if (((isset($context["severity"]) || array_key_exists("severity", $context) ? $context["severity"] : (function () { throw new RuntimeError('Variable "severity" does not exist.', 29, $this->source); })()) == 1)) {
            // line 30
            echo "  ";
            $context["severityClass"] = "success";
            // line 31
            echo "  ";
            $context["severityMessage"] = (((isset($context["withMessage"]) || array_key_exists("withMessage", $context) ? $context["withMessage"] : (function () { throw new RuntimeError('Variable "withMessage" does not exist.', 31, $this->source); })())) ? ($this->extensions['Symfony\Bridge\Twig\Extension\TranslationExtension']->trans("Informative only", [], "Admin.Advparameters.Help")) : (""));
        } elseif ((        // line 32
(isset($context["severity"]) || array_key_exists("severity", $context) ? $context["severity"] : (function () { throw new RuntimeError('Variable "severity" does not exist.', 32, $this->source); })()) == 2)) {
            // line 33
            echo "  ";
            $context["severityClass"] = "warning";
            // line 34
            echo "  ";
            $context["severityMessage"] = (((isset($context["withMessage"]) || array_key_exists("withMessage", $context) ? $context["withMessage"] : (function () { throw new RuntimeError('Variable "withMessage" does not exist.', 34, $this->source); })())) ? ($this->extensions['Symfony\Bridge\Twig\Extension\TranslationExtension']->trans("Warning", [], "Admin.Advparameters.Help")) : (""));
        } elseif ((        // line 35
(isset($context["severity"]) || array_key_exists("severity", $context) ? $context["severity"] : (function () { throw new RuntimeError('Variable "severity" does not exist.', 35, $this->source); })()) == 3)) {
            // line 36
            echo "  ";
            $context["severityClass"] = "danger";
            // line 37
            echo "  ";
            $context["severityMessage"] = (((isset($context["withMessage"]) || array_key_exists("withMessage", $context) ? $context["withMessage"] : (function () { throw new RuntimeError('Variable "withMessage" does not exist.', 37, $this->source); })())) ? ($this->extensions['Symfony\Bridge\Twig\Extension\TranslationExtension']->trans("Error", [], "Admin.Advparameters.Help")) : (""));
        } elseif ((        // line 38
(isset($context["severity"]) || array_key_exists("severity", $context) ? $context["severity"] : (function () { throw new RuntimeError('Variable "severity" does not exist.', 38, $this->source); })()) == 4)) {
            // line 39
            echo "  ";
            $context["severityClass"] = "dark";
            // line 40
            echo "  ";
            $context["severityMessage"] = (((isset($context["withMessage"]) || array_key_exists("withMessage", $context) ? $context["withMessage"] : (function () { throw new RuntimeError('Variable "withMessage" does not exist.', 40, $this->source); })())) ? ($this->extensions['Symfony\Bridge\Twig\Extension\TranslationExtension']->trans("Major issue (crash)!", [], "Admin.Advparameters.Help")) : (""));
        } else {
            // line 42
            echo "  ";
            $context["severityClass"] = "";
            // line 43
            echo "  ";
            $context["severityMessage"] = "";
        }
        // line 45
        echo "
<span class=\"badge badge-pill badge-";
        // line 46
        echo twig_escape_filter($this->env, (isset($context["severityClass"]) || array_key_exists("severityClass", $context) ? $context["severityClass"] : (function () { throw new RuntimeError('Variable "severityClass" does not exist.', 46, $this->source); })()), "html", null, true);
        echo "\">
  ";
        // line 47
        if ((isset($context["withMessage"]) || array_key_exists("withMessage", $context) ? $context["withMessage"] : (function () { throw new RuntimeError('Variable "withMessage" does not exist.', 47, $this->source); })())) {
            // line 48
            echo "    ";
            echo twig_escape_filter($this->env, (isset($context["severityMessage"]) || array_key_exists("severityMessage", $context) ? $context["severityMessage"] : (function () { throw new RuntimeError('Variable "severityMessage" does not exist.', 48, $this->source); })()), "html", null, true);
            echo " (";
            echo twig_escape_filter($this->env, (isset($context["severity"]) || array_key_exists("severity", $context) ? $context["severity"] : (function () { throw new RuntimeError('Variable "severity" does not exist.', 48, $this->source); })()), "html", null, true);
            echo ")
  ";
        } else {
            // line 50
            echo "    ";
            echo twig_escape_filter($this->env, (isset($context["severity"]) || array_key_exists("severity", $context) ? $context["severity"] : (function () { throw new RuntimeError('Variable "severity" does not exist.', 50, $this->source); })()), "html", null, true);
            echo "
  ";
        }
        // line 52
        echo "</span>
";
        
        $__internal_5a27a8ba21ca79b61932376b2fa922d2->leave($__internal_5a27a8ba21ca79b61932376b2fa922d2_prof);

        
        $__internal_6f47bbe9983af81f1e7450e9a3e3768f->leave($__internal_6f47bbe9983af81f1e7450e9a3e3768f_prof);

    }

    public function getTemplateName()
    {
        return "@PrestaShop/Admin/Common/Grid/Columns/Content/severity_level.html.twig";
    }

    public function isTraitable()
    {
        return false;
    }

    public function getDebugInfo()
    {
        return array (  116 => 52,  110 => 50,  102 => 48,  100 => 47,  96 => 46,  93 => 45,  89 => 43,  86 => 42,  82 => 40,  79 => 39,  77 => 38,  74 => 37,  71 => 36,  69 => 35,  66 => 34,  63 => 33,  61 => 32,  58 => 31,  55 => 30,  53 => 29,  50 => 28,  48 => 27,  46 => 26,  43 => 25,);
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

{% set severity = record.severity %}
{% set withMessage = column.options.with_message %}

{% if severity == 1 %}
  {% set severityClass = 'success' %}
  {% set severityMessage = withMessage ? 'Informative only'|trans({}, 'Admin.Advparameters.Help') : '' %}
{% elseif severity == 2 %}
  {% set severityClass = 'warning' %}
  {% set severityMessage = withMessage ? 'Warning'|trans({}, 'Admin.Advparameters.Help') : '' %}
{% elseif severity == 3 %}
  {% set severityClass = 'danger' %}
  {% set severityMessage = withMessage ? 'Error'|trans({}, 'Admin.Advparameters.Help') : '' %}
{% elseif severity == 4 %}
  {% set severityClass = 'dark' %}
  {% set severityMessage = withMessage ? 'Major issue (crash)!'|trans({}, 'Admin.Advparameters.Help') : '' %}
{% else %}
  {% set severityClass = '' %}
  {% set severityMessage = '' %}
{% endif %}

<span class=\"badge badge-pill badge-{{ severityClass }}\">
  {% if withMessage %}
    {{ severityMessage }} ({{ severity }})
  {% else %}
    {{ severity }}
  {% endif %}
</span>
", "@PrestaShop/Admin/Common/Grid/Columns/Content/severity_level.html.twig", "/var/www/html/src/PrestaShopBundle/Resources/views/Admin/Common/Grid/Columns/Content/severity_level.html.twig");
    }
}
