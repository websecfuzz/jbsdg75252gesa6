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

/* @PrestaShop/Admin/Common/Grid/Columns/Content/badge.html.twig */
class __TwigTemplate_bb57a35a11ce1eccf216a73034cab76b extends Template
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
        $__internal_5a27a8ba21ca79b61932376b2fa922d2->enter($__internal_5a27a8ba21ca79b61932376b2fa922d2_prof = new \Twig\Profiler\Profile($this->getTemplateName(), "template", "@PrestaShop/Admin/Common/Grid/Columns/Content/badge.html.twig"));

        $__internal_6f47bbe9983af81f1e7450e9a3e3768f = $this->extensions["Symfony\\Bridge\\Twig\\Extension\\ProfilerExtension"];
        $__internal_6f47bbe9983af81f1e7450e9a3e3768f->enter($__internal_6f47bbe9983af81f1e7450e9a3e3768f_prof = new \Twig\Profiler\Profile($this->getTemplateName(), "template", "@PrestaShop/Admin/Common/Grid/Columns/Content/badge.html.twig"));

        // line 25
        echo "
<div class=\"text-right\">
";
        // line 27
        if (( !twig_test_empty(twig_get_attribute($this->env, $this->source, (isset($context["record"]) || array_key_exists("record", $context) ? $context["record"] : (function () { throw new RuntimeError('Variable "record" does not exist.', 27, $this->source); })()), twig_get_attribute($this->env, $this->source, twig_get_attribute($this->env, $this->source, (isset($context["column"]) || array_key_exists("column", $context) ? $context["column"] : (function () { throw new RuntimeError('Variable "column" does not exist.', 27, $this->source); })()), "options", [], "any", false, false, false, 27), "field", [], "any", false, false, false, 27), [], "array", false, false, false, 27)) &&  !twig_test_empty(twig_get_attribute($this->env, $this->source, twig_get_attribute($this->env, $this->source, (isset($context["column"]) || array_key_exists("column", $context) ? $context["column"] : (function () { throw new RuntimeError('Variable "column" does not exist.', 27, $this->source); })()), "options", [], "any", false, false, false, 27), "badge_type", [], "any", false, false, false, 27)))) {
            // line 28
            echo "  <span class=\"badge rounded badge-";
            echo twig_escape_filter($this->env, twig_get_attribute($this->env, $this->source, twig_get_attribute($this->env, $this->source, (isset($context["column"]) || array_key_exists("column", $context) ? $context["column"] : (function () { throw new RuntimeError('Variable "column" does not exist.', 28, $this->source); })()), "options", [], "any", false, false, false, 28), "badge_type", [], "any", false, false, false, 28), "html", null, true);
            echo "\">
    ";
            // line 29
            echo twig_escape_filter($this->env, twig_get_attribute($this->env, $this->source, (isset($context["record"]) || array_key_exists("record", $context) ? $context["record"] : (function () { throw new RuntimeError('Variable "record" does not exist.', 29, $this->source); })()), twig_get_attribute($this->env, $this->source, twig_get_attribute($this->env, $this->source, (isset($context["column"]) || array_key_exists("column", $context) ? $context["column"] : (function () { throw new RuntimeError('Variable "column" does not exist.', 29, $this->source); })()), "options", [], "any", false, false, false, 29), "field", [], "any", false, false, false, 29), [], "array", false, false, false, 29), "html", null, true);
            echo "
  </span>
";
        } elseif ((( !twig_test_empty(twig_get_attribute($this->env, $this->source,         // line 31
(isset($context["record"]) || array_key_exists("record", $context) ? $context["record"] : (function () { throw new RuntimeError('Variable "record" does not exist.', 31, $this->source); })()), twig_get_attribute($this->env, $this->source, twig_get_attribute($this->env, $this->source, (isset($context["column"]) || array_key_exists("column", $context) ? $context["column"] : (function () { throw new RuntimeError('Variable "column" does not exist.', 31, $this->source); })()), "options", [], "any", false, false, false, 31), "field", [], "any", false, false, false, 31), [], "array", false, false, false, 31)) && twig_in_filter(twig_get_attribute($this->env, $this->source, twig_get_attribute($this->env, $this->source, (isset($context["column"]) || array_key_exists("column", $context) ? $context["column"] : (function () { throw new RuntimeError('Variable "column" does not exist.', 31, $this->source); })()), "options", [], "any", false, false, false, 31), "color_field", [], "any", false, false, false, 31), twig_get_array_keys_filter((isset($context["record"]) || array_key_exists("record", $context) ? $context["record"] : (function () { throw new RuntimeError('Variable "record" does not exist.', 31, $this->source); })())))) &&  !twig_test_empty(twig_get_attribute($this->env, $this->source, (isset($context["record"]) || array_key_exists("record", $context) ? $context["record"] : (function () { throw new RuntimeError('Variable "record" does not exist.', 31, $this->source); })()), twig_get_attribute($this->env, $this->source, twig_get_attribute($this->env, $this->source, (isset($context["column"]) || array_key_exists("column", $context) ? $context["column"] : (function () { throw new RuntimeError('Variable "column" does not exist.', 31, $this->source); })()), "options", [], "any", false, false, false, 31), "color_field", [], "any", false, false, false, 31), [], "array", false, false, false, 31)))) {
            // line 32
            echo "  ";
            $context["textColor"] = (($this->env->getFunction('is_color_bright')->getCallable()(twig_get_attribute($this->env, $this->source, (isset($context["record"]) || array_key_exists("record", $context) ? $context["record"] : (function () { throw new RuntimeError('Variable "record" does not exist.', 32, $this->source); })()), twig_get_attribute($this->env, $this->source, twig_get_attribute($this->env, $this->source, (isset($context["column"]) || array_key_exists("column", $context) ? $context["column"] : (function () { throw new RuntimeError('Variable "column" does not exist.', 32, $this->source); })()), "options", [], "any", false, false, false, 32), "color_field", [], "any", false, false, false, 32), [], "array", false, false, false, 32))) ? ("#383838") : ("white"));
            // line 33
            echo "  <span class=\"badge rounded\" style=\"background-color: ";
            echo twig_escape_filter($this->env, twig_get_attribute($this->env, $this->source, (isset($context["record"]) || array_key_exists("record", $context) ? $context["record"] : (function () { throw new RuntimeError('Variable "record" does not exist.', 33, $this->source); })()), twig_get_attribute($this->env, $this->source, twig_get_attribute($this->env, $this->source, (isset($context["column"]) || array_key_exists("column", $context) ? $context["column"] : (function () { throw new RuntimeError('Variable "column" does not exist.', 33, $this->source); })()), "options", [], "any", false, false, false, 33), "color_field", [], "any", false, false, false, 33), [], "array", false, false, false, 33), "html", null, true);
            echo "; color: ";
            echo twig_escape_filter($this->env, (isset($context["textColor"]) || array_key_exists("textColor", $context) ? $context["textColor"] : (function () { throw new RuntimeError('Variable "textColor" does not exist.', 33, $this->source); })()), "html", null, true);
            echo "\">
    ";
            // line 34
            echo twig_escape_filter($this->env, twig_get_attribute($this->env, $this->source, (isset($context["record"]) || array_key_exists("record", $context) ? $context["record"] : (function () { throw new RuntimeError('Variable "record" does not exist.', 34, $this->source); })()), twig_get_attribute($this->env, $this->source, twig_get_attribute($this->env, $this->source, (isset($context["column"]) || array_key_exists("column", $context) ? $context["column"] : (function () { throw new RuntimeError('Variable "column" does not exist.', 34, $this->source); })()), "options", [], "any", false, false, false, 34), "field", [], "any", false, false, false, 34), [], "array", false, false, false, 34), "html", null, true);
            echo "
  </span>
";
        } elseif ( !twig_test_empty(twig_get_attribute($this->env, $this->source,         // line 36
(isset($context["record"]) || array_key_exists("record", $context) ? $context["record"] : (function () { throw new RuntimeError('Variable "record" does not exist.', 36, $this->source); })()), twig_get_attribute($this->env, $this->source, twig_get_attribute($this->env, $this->source, (isset($context["column"]) || array_key_exists("column", $context) ? $context["column"] : (function () { throw new RuntimeError('Variable "column" does not exist.', 36, $this->source); })()), "options", [], "any", false, false, false, 36), "field", [], "any", false, false, false, 36), [], "array", false, false, false, 36))) {
            // line 37
            echo "  ";
            echo twig_escape_filter($this->env, twig_get_attribute($this->env, $this->source, (isset($context["record"]) || array_key_exists("record", $context) ? $context["record"] : (function () { throw new RuntimeError('Variable "record" does not exist.', 37, $this->source); })()), twig_get_attribute($this->env, $this->source, twig_get_attribute($this->env, $this->source, (isset($context["column"]) || array_key_exists("column", $context) ? $context["column"] : (function () { throw new RuntimeError('Variable "column" does not exist.', 37, $this->source); })()), "options", [], "any", false, false, false, 37), "field", [], "any", false, false, false, 37), [], "array", false, false, false, 37), "html", null, true);
            echo "
";
        } else {
            // line 39
            echo "  ";
            echo twig_escape_filter($this->env, twig_get_attribute($this->env, $this->source, twig_get_attribute($this->env, $this->source, (isset($context["column"]) || array_key_exists("column", $context) ? $context["column"] : (function () { throw new RuntimeError('Variable "column" does not exist.', 39, $this->source); })()), "options", [], "any", false, false, false, 39), "empty_value", [], "any", false, false, false, 39), "html", null, true);
            echo "
";
        }
        // line 41
        echo "</div>
";
        
        $__internal_5a27a8ba21ca79b61932376b2fa922d2->leave($__internal_5a27a8ba21ca79b61932376b2fa922d2_prof);

        
        $__internal_6f47bbe9983af81f1e7450e9a3e3768f->leave($__internal_6f47bbe9983af81f1e7450e9a3e3768f_prof);

    }

    public function getTemplateName()
    {
        return "@PrestaShop/Admin/Common/Grid/Columns/Content/badge.html.twig";
    }

    public function isTraitable()
    {
        return false;
    }

    public function getDebugInfo()
    {
        return array (  90 => 41,  84 => 39,  78 => 37,  76 => 36,  71 => 34,  64 => 33,  61 => 32,  59 => 31,  54 => 29,  49 => 28,  47 => 27,  43 => 25,);
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

<div class=\"text-right\">
{% if record[column.options.field] is not empty and column.options.badge_type is not empty %}
  <span class=\"badge rounded badge-{{ column.options.badge_type }}\">
    {{ record[column.options.field] }}
  </span>
{% elseif record[column.options.field] is not empty and column.options.color_field in record|keys and record[column.options.color_field] is not empty %}
  {% set textColor = is_color_bright(record[column.options.color_field]) ? '#383838' : 'white' %}
  <span class=\"badge rounded\" style=\"background-color: {{ record[column.options.color_field] }}; color: {{ textColor }}\">
    {{ record[column.options.field] }}
  </span>
{% elseif record[column.options.field] is not empty %}
  {{ record[column.options.field] }}
{% else %}
  {{ column.options.empty_value }}
{% endif %}
</div>
", "@PrestaShop/Admin/Common/Grid/Columns/Content/badge.html.twig", "/var/www/html/src/PrestaShopBundle/Resources/views/Admin/Common/Grid/Columns/Content/badge.html.twig");
    }
}
