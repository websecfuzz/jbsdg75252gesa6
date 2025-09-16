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

/* @PrestaShop/Admin/Common/Grid/Blocks/Table/empty_row.html.twig */
class __TwigTemplate_98d006d15c983f2745df9cf9f246fc0a extends Template
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
        $__internal_5a27a8ba21ca79b61932376b2fa922d2->enter($__internal_5a27a8ba21ca79b61932376b2fa922d2_prof = new \Twig\Profiler\Profile($this->getTemplateName(), "template", "@PrestaShop/Admin/Common/Grid/Blocks/Table/empty_row.html.twig"));

        $__internal_6f47bbe9983af81f1e7450e9a3e3768f = $this->extensions["Symfony\\Bridge\\Twig\\Extension\\ProfilerExtension"];
        $__internal_6f47bbe9983af81f1e7450e9a3e3768f->enter($__internal_6f47bbe9983af81f1e7450e9a3e3768f_prof = new \Twig\Profiler\Profile($this->getTemplateName(), "template", "@PrestaShop/Admin/Common/Grid/Blocks/Table/empty_row.html.twig"));

        // line 25
        echo "
<tr class=\"empty_row\">
  <td colspan=\"";
        // line 27
        echo twig_escape_filter($this->env, twig_length_filter($this->env, twig_get_attribute($this->env, $this->source, (isset($context["grid"]) || array_key_exists("grid", $context) ? $context["grid"] : (function () { throw new RuntimeError('Variable "grid" does not exist.', 27, $this->source); })()), "columns", [], "any", false, false, false, 27)), "html", null, true);
        echo "\" ";
        if (twig_get_attribute($this->env, $this->source, twig_get_attribute($this->env, $this->source, (isset($context["grid"]) || array_key_exists("grid", $context) ? $context["grid"] : (function () { throw new RuntimeError('Variable "grid" does not exist.', 27, $this->source); })()), "attributes", [], "any", false, false, false, 27), "is_empty_state", [], "any", false, false, false, 27)) {
            echo "class=\"border-0\"";
        }
        echo ">
    ";
        // line 28
        if (twig_get_attribute($this->env, $this->source, twig_get_attribute($this->env, $this->source, (isset($context["grid"]) || array_key_exists("grid", $context) ? $context["grid"] : (function () { throw new RuntimeError('Variable "grid" does not exist.', 28, $this->source); })()), "attributes", [], "any", false, false, false, 28), "is_empty_state", [], "any", false, false, false, 28)) {
            // line 29
            echo "      ";
            $this->loadTemplate([0 => (("@PrestaShop/Admin/Common/Grid/Blocks/EmptyState/" . twig_get_attribute($this->env, $this->source,             // line 30
(isset($context["grid"]) || array_key_exists("grid", $context) ? $context["grid"] : (function () { throw new RuntimeError('Variable "grid" does not exist.', 30, $this->source); })()), "id", [], "any", false, false, false, 30)) . ".html.twig"), 1 => "@PrestaShop/Admin/Common/Grid/Blocks/EmptyState/_default.html.twig"], "@PrestaShop/Admin/Common/Grid/Blocks/Table/empty_row.html.twig", 29)->display(twig_array_merge($context, ["grid" =>             // line 32
(isset($context["grid"]) || array_key_exists("grid", $context) ? $context["grid"] : (function () { throw new RuntimeError('Variable "grid" does not exist.', 32, $this->source); })())]));
            // line 34
            echo "    ";
        } else {
            // line 35
            echo "      ";
            $this->loadTemplate("@PrestaShop/Admin/Common/Grid/Blocks/EmptyState/_default.html.twig", "@PrestaShop/Admin/Common/Grid/Blocks/Table/empty_row.html.twig", 35)->display(twig_array_merge($context, ["grid" => (isset($context["grid"]) || array_key_exists("grid", $context) ? $context["grid"] : (function () { throw new RuntimeError('Variable "grid" does not exist.', 35, $this->source); })())]));
            // line 36
            echo "    ";
        }
        // line 37
        echo "  </td>
</tr>
";
        
        $__internal_5a27a8ba21ca79b61932376b2fa922d2->leave($__internal_5a27a8ba21ca79b61932376b2fa922d2_prof);

        
        $__internal_6f47bbe9983af81f1e7450e9a3e3768f->leave($__internal_6f47bbe9983af81f1e7450e9a3e3768f_prof);

    }

    public function getTemplateName()
    {
        return "@PrestaShop/Admin/Common/Grid/Blocks/Table/empty_row.html.twig";
    }

    public function isTraitable()
    {
        return false;
    }

    public function getDebugInfo()
    {
        return array (  71 => 37,  68 => 36,  65 => 35,  62 => 34,  60 => 32,  59 => 30,  57 => 29,  55 => 28,  47 => 27,  43 => 25,);
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

<tr class=\"empty_row\">
  <td colspan=\"{{ grid.columns|length }}\" {% if grid.attributes.is_empty_state %}class=\"border-0\"{% endif %}>
    {% if grid.attributes.is_empty_state %}
      {% include [
        '@PrestaShop/Admin/Common/Grid/Blocks/EmptyState/'~grid.id~'.html.twig',
        '@PrestaShop/Admin/Common/Grid/Blocks/EmptyState/_default.html.twig'
        ] with {'grid': grid}
      %}
    {% else %}
      {% include '@PrestaShop/Admin/Common/Grid/Blocks/EmptyState/_default.html.twig' with {'grid': grid} %}
    {% endif %}
  </td>
</tr>
", "@PrestaShop/Admin/Common/Grid/Blocks/Table/empty_row.html.twig", "/var/www/html/src/PrestaShopBundle/Resources/views/Admin/Common/Grid/Blocks/Table/empty_row.html.twig");
    }
}
