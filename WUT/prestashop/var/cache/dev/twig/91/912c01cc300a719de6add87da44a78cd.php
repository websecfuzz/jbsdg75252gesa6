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

/* @PrestaShop/Admin/Helpers/password_feedback.html.twig */
class __TwigTemplate_19bd56ce50bde59471aa27ea560f870c extends Template
{
    private $source;
    private $macros = [];

    public function __construct(Environment $env)
    {
        parent::__construct($env);

        $this->source = $this->getSourceContext();

        $this->parent = false;

        $this->blocks = [
            'password_feedback_block' => [$this, 'block_password_feedback_block'],
        ];
    }

    protected function doDisplay(array $context, array $blocks = [])
    {
        $macros = $this->macros;
        $__internal_5a27a8ba21ca79b61932376b2fa922d2 = $this->extensions["Symfony\\Bundle\\WebProfilerBundle\\Twig\\WebProfilerExtension"];
        $__internal_5a27a8ba21ca79b61932376b2fa922d2->enter($__internal_5a27a8ba21ca79b61932376b2fa922d2_prof = new \Twig\Profiler\Profile($this->getTemplateName(), "template", "@PrestaShop/Admin/Helpers/password_feedback.html.twig"));

        $__internal_6f47bbe9983af81f1e7450e9a3e3768f = $this->extensions["Symfony\\Bridge\\Twig\\Extension\\ProfilerExtension"];
        $__internal_6f47bbe9983af81f1e7450e9a3e3768f->enter($__internal_6f47bbe9983af81f1e7450e9a3e3768f_prof = new \Twig\Profiler\Profile($this->getTemplateName(), "template", "@PrestaShop/Admin/Helpers/password_feedback.html.twig"));

        // line 25
        echo "
";
        // line 26
        $this->displayBlock('password_feedback_block', $context, $blocks);
        
        $__internal_5a27a8ba21ca79b61932376b2fa922d2->leave($__internal_5a27a8ba21ca79b61932376b2fa922d2_prof);

        
        $__internal_6f47bbe9983af81f1e7450e9a3e3768f->leave($__internal_6f47bbe9983af81f1e7450e9a3e3768f_prof);

    }

    public function block_password_feedback_block($context, array $blocks = [])
    {
        $macros = $this->macros;
        $__internal_5a27a8ba21ca79b61932376b2fa922d2 = $this->extensions["Symfony\\Bundle\\WebProfilerBundle\\Twig\\WebProfilerExtension"];
        $__internal_5a27a8ba21ca79b61932376b2fa922d2->enter($__internal_5a27a8ba21ca79b61932376b2fa922d2_prof = new \Twig\Profiler\Profile($this->getTemplateName(), "block", "password_feedback_block"));

        $__internal_6f47bbe9983af81f1e7450e9a3e3768f = $this->extensions["Symfony\\Bridge\\Twig\\Extension\\ProfilerExtension"];
        $__internal_6f47bbe9983af81f1e7450e9a3e3768f->enter($__internal_6f47bbe9983af81f1e7450e9a3e3768f_prof = new \Twig\Profiler\Profile($this->getTemplateName(), "block", "password_feedback_block"));

        // line 27
        echo "  <template id=\"password-feedback\">
    ";
        // line 29
        echo "    <div
      class=\"password-strength-feedback d-none\"
      data-translations=\"";
        // line 31
        echo twig_escape_filter($this->env, json_encode(["Straight rows of keys are easy to guess" => $this->extensions['Symfony\Bridge\Twig\Extension\TranslationExtension']->trans("Straight rows of keys are easy to guess", [], "Admin.Advparameters.Feature"), "Short keyboard patterns are easy to guess" => $this->extensions['Symfony\Bridge\Twig\Extension\TranslationExtension']->trans("Short keyboard patterns are easy to guess", [], "Admin.Advparameters.Feature"), "Use a longer keyboard pattern with more turns" => $this->extensions['Symfony\Bridge\Twig\Extension\TranslationExtension']->trans("Use a longer keyboard pattern with more turns", [], "Admin.Advparameters.Feature"), "Repeats like \"aaa\" are easy to guess" => $this->extensions['Symfony\Bridge\Twig\Extension\TranslationExtension']->trans("Repeats like \"aaa\" are easy to guess", [], "Admin.Advparameters.Feature"), "Repeats like \"abcabcabc\" are only slightly harder to guess than \"abc\"" => $this->extensions['Symfony\Bridge\Twig\Extension\TranslationExtension']->trans("Repeats like \"abcabcabc\" are only slightly harder to guess than \"abc\"", [], "Admin.Advparameters.Feature"), "Sequences like abc or 6543 are easy to guess" => $this->extensions['Symfony\Bridge\Twig\Extension\TranslationExtension']->trans("Sequences like \"abc\" or \"6543\" are easy to guess", [], "Admin.Advparameters.Feature"), "Recent years are easy to guess" => $this->extensions['Symfony\Bridge\Twig\Extension\TranslationExtension']->trans("Recent years are easy to guess", [], "Admin.Advparameters.Feature"), "Dates are often easy to guess" => $this->extensions['Symfony\Bridge\Twig\Extension\TranslationExtension']->trans("Dates are often easy to guess", [], "Admin.Advparameters.Feature"), "This is a top-10 common password" => $this->extensions['Symfony\Bridge\Twig\Extension\TranslationExtension']->trans("This is a top-10 common password", [], "Admin.Advparameters.Feature"), "This is a top-100 common password" => $this->extensions['Symfony\Bridge\Twig\Extension\TranslationExtension']->trans("This is a top-100 common password", [], "Admin.Advparameters.Feature"), "This is a very common password" => $this->extensions['Symfony\Bridge\Twig\Extension\TranslationExtension']->trans("This is a very common password", [], "Admin.Advparameters.Feature"), "This is similar to a commonly used password" => $this->extensions['Symfony\Bridge\Twig\Extension\TranslationExtension']->trans("This is similar to a commonly used password", [], "Admin.Advparameters.Feature"), "A word by itself is easy to guess" => $this->extensions['Symfony\Bridge\Twig\Extension\TranslationExtension']->trans("A word by itself is easy to guess", [], "Admin.Advparameters.Feature"), "Names and surnames by themselves are easy to guess" => $this->extensions['Symfony\Bridge\Twig\Extension\TranslationExtension']->trans("Names and surnames by themselves are easy to guess", [], "Admin.Advparameters.Feature"), "Common names and surnames are easy to guess" => $this->extensions['Symfony\Bridge\Twig\Extension\TranslationExtension']->trans("Common names and surnames are easy to guess", [], "Admin.Advparameters.Feature"), 0 => $this->extensions['Symfony\Bridge\Twig\Extension\TranslationExtension']->trans("Very weak", [], "Admin.Advparameters.Feature"), 1 => $this->extensions['Symfony\Bridge\Twig\Extension\TranslationExtension']->trans("Weak", [], "Admin.Advparameters.Feature"), 2 => $this->extensions['Symfony\Bridge\Twig\Extension\TranslationExtension']->trans("Average", [], "Admin.Advparameters.Feature"), 3 => $this->extensions['Symfony\Bridge\Twig\Extension\TranslationExtension']->trans("Strong", [], "Admin.Advparameters.Feature"), 4 => $this->extensions['Symfony\Bridge\Twig\Extension\TranslationExtension']->trans("Very strong", [], "Admin.Advparameters.Feature"), "Use a few words, avoid common phrases" => $this->extensions['Symfony\Bridge\Twig\Extension\TranslationExtension']->trans("Use a few words, avoid common phrases", [], "Admin.Advparameters.Feature"), "No need for symbols, digits, or uppercase letters" => $this->extensions['Symfony\Bridge\Twig\Extension\TranslationExtension']->trans("No need for symbols, digits, or uppercase letters", [], "Admin.Advparameters.Feature"), "Avoid repeated words and characters" => $this->extensions['Symfony\Bridge\Twig\Extension\TranslationExtension']->trans("Avoid repeated words and characters", [], "Admin.Advparameters.Feature"), "Avoid sequences" => $this->extensions['Symfony\Bridge\Twig\Extension\TranslationExtension']->trans("Avoid sequences", [], "Admin.Advparameters.Feature"), "Avoid recent years" => $this->extensions['Symfony\Bridge\Twig\Extension\TranslationExtension']->trans("Avoid recent years", [], "Admin.Advparameters.Feature"), "Avoid years that are associated with you" => $this->extensions['Symfony\Bridge\Twig\Extension\TranslationExtension']->trans("Avoid years that are associated with you", [], "Admin.Advparameters.Feature"), "Avoid dates and years that are associated with you" => $this->extensions['Symfony\Bridge\Twig\Extension\TranslationExtension']->trans("Avoid dates and years that are associated with you", [], "Admin.Advparameters.Feature"), "Capitalization doesn't help very much" => $this->extensions['Symfony\Bridge\Twig\Extension\TranslationExtension']->trans("Capitalization doesn't help very much", [], "Admin.Advparameters.Feature"), "All-uppercase is almost as easy to guess as all-lowercase" => $this->extensions['Symfony\Bridge\Twig\Extension\TranslationExtension']->trans("All-uppercase is almost as easy to guess as all-lowercase", [], "Admin.Advparameters.Feature"), "Reversed words aren't much harder to guess" => $this->extensions['Symfony\Bridge\Twig\Extension\TranslationExtension']->trans("Reversed words aren't much harder to guess", [], "Admin.Advparameters.Feature"), "Predictable substitutions like '@' instead of 'a' don't help very much" => $this->extensions['Symfony\Bridge\Twig\Extension\TranslationExtension']->trans("Predictable substitutions like \"@\" instead of \"a\" don't help very much", [], "Admin.Advparameters.Feature"), "Add another word or two. Uncommon words are better." => $this->extensions['Symfony\Bridge\Twig\Extension\TranslationExtension']->trans("Add another word or two. Uncommon words are better.", [], "Admin.Advparameters.Feature")]), "html_attr");
        // line 64
        echo "\"
    >
      <div class=\"progress-container\">
        <div class=\"progress-bar\">
          <div></div>
        </div>
      </div>
      <div class=\"password-strength-text\"></div>
      <div class=\"password-requirements\">
        <p class=\"password-requirements-length\" data-translation=\"";
        // line 73
        echo twig_escape_filter($this->env, $this->extensions['Symfony\Bridge\Twig\Extension\TranslationExtension']->trans("Enter a password between %d and %d characters", [], "Admin.Advparameters.Feature"), "html_attr");
        echo "\">
          <i class=\"material-icons\">check_circle</i>
          <span></span>
        </p>
        <p class=\"password-requirements-score\" data-translation=\"";
        // line 77
        echo twig_escape_filter($this->env, $this->extensions['Symfony\Bridge\Twig\Extension\TranslationExtension']->trans("The minimum score must be: %s", [], "Admin.Advparameters.Feature"), "html_attr");
        echo "\">
          <i class=\"material-icons\">check_circle</i>
          <span></span>
        </p>
      </div>
    </div>
  </template>
";
        
        $__internal_6f47bbe9983af81f1e7450e9a3e3768f->leave($__internal_6f47bbe9983af81f1e7450e9a3e3768f_prof);

        
        $__internal_5a27a8ba21ca79b61932376b2fa922d2->leave($__internal_5a27a8ba21ca79b61932376b2fa922d2_prof);

    }

    public function getTemplateName()
    {
        return "@PrestaShop/Admin/Helpers/password_feedback.html.twig";
    }

    public function getDebugInfo()
    {
        return array (  93 => 77,  86 => 73,  75 => 64,  73 => 31,  69 => 29,  66 => 27,  47 => 26,  44 => 25,);
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

{% block password_feedback_block %}
  <template id=\"password-feedback\">
    {# Password strength feedback messages - used in JS #}
    <div
      class=\"password-strength-feedback d-none\"
      data-translations=\"{{ {
                           'Straight rows of keys are easy to guess': 'Straight rows of keys are easy to guess'|trans({}, 'Admin.Advparameters.Feature'),
                           'Short keyboard patterns are easy to guess': 'Short keyboard patterns are easy to guess'|trans({}, 'Admin.Advparameters.Feature'),
                           'Use a longer keyboard pattern with more turns': 'Use a longer keyboard pattern with more turns'|trans({}, 'Admin.Advparameters.Feature'),
                           'Repeats like \"aaa\" are easy to guess': 'Repeats like \"aaa\" are easy to guess'|trans({}, 'Admin.Advparameters.Feature'),
                           'Repeats like \"abcabcabc\" are only slightly harder to guess than \"abc\"': 'Repeats like \"abcabcabc\" are only slightly harder to guess than \"abc\"'|trans({}, 'Admin.Advparameters.Feature'),
                           'Sequences like abc or 6543 are easy to guess': 'Sequences like \"abc\" or \"6543\" are easy to guess'|trans({}, 'Admin.Advparameters.Feature'),
                           'Recent years are easy to guess': 'Recent years are easy to guess'|trans({}, 'Admin.Advparameters.Feature'),
                           'Dates are often easy to guess': 'Dates are often easy to guess'|trans({}, 'Admin.Advparameters.Feature'),
                           'This is a top-10 common password': 'This is a top-10 common password'|trans({}, 'Admin.Advparameters.Feature'),
                           'This is a top-100 common password': 'This is a top-100 common password'|trans({}, 'Admin.Advparameters.Feature'),
                           'This is a very common password': 'This is a very common password'|trans({}, 'Admin.Advparameters.Feature'),
                           'This is similar to a commonly used password': 'This is similar to a commonly used password'|trans({}, 'Admin.Advparameters.Feature'),
                           'A word by itself is easy to guess': 'A word by itself is easy to guess'|trans({}, 'Admin.Advparameters.Feature'),
                           'Names and surnames by themselves are easy to guess': 'Names and surnames by themselves are easy to guess'|trans({}, 'Admin.Advparameters.Feature'),
                           'Common names and surnames are easy to guess': 'Common names and surnames are easy to guess'|trans({}, 'Admin.Advparameters.Feature'),
                           0: 'Very weak'|trans({}, 'Admin.Advparameters.Feature'),
                           1: 'Weak'|trans({}, 'Admin.Advparameters.Feature'),
                           2: 'Average'|trans({}, 'Admin.Advparameters.Feature'),
                           3: 'Strong'|trans({}, 'Admin.Advparameters.Feature'),
                           4: 'Very strong'|trans({}, 'Admin.Advparameters.Feature'),
                           'Use a few words, avoid common phrases': 'Use a few words, avoid common phrases'|trans({}, 'Admin.Advparameters.Feature'),
                           'No need for symbols, digits, or uppercase letters': 'No need for symbols, digits, or uppercase letters'|trans({}, 'Admin.Advparameters.Feature'),
                           'Avoid repeated words and characters': 'Avoid repeated words and characters'|trans({}, 'Admin.Advparameters.Feature'),
                           'Avoid sequences': 'Avoid sequences'|trans({}, 'Admin.Advparameters.Feature'),
                           'Avoid recent years': 'Avoid recent years'|trans({}, 'Admin.Advparameters.Feature'),
                           'Avoid years that are associated with you': 'Avoid years that are associated with you'|trans({}, 'Admin.Advparameters.Feature'),
                           'Avoid dates and years that are associated with you': 'Avoid dates and years that are associated with you'|trans({}, 'Admin.Advparameters.Feature'),
                           'Capitalization doesn\\'t help very much': 'Capitalization doesn\\'t help very much'|trans({}, 'Admin.Advparameters.Feature'),
                           'All-uppercase is almost as easy to guess as all-lowercase': 'All-uppercase is almost as easy to guess as all-lowercase'|trans({}, 'Admin.Advparameters.Feature'),
                           'Reversed words aren\\'t much harder to guess': 'Reversed words aren\\'t much harder to guess'|trans({}, 'Admin.Advparameters.Feature'),
                           'Predictable substitutions like \\'@\\' instead of \\'a\\' don\\'t help very much': 'Predictable substitutions like \"@\" instead of \"a\" don\\'t help very much'|trans({}, 'Admin.Advparameters.Feature'),
                           'Add another word or two. Uncommon words are better.': 'Add another word or two. Uncommon words are better.'|trans({}, 'Admin.Advparameters.Feature'),
                           }|json_encode|escape('html_attr') }}\"
    >
      <div class=\"progress-container\">
        <div class=\"progress-bar\">
          <div></div>
        </div>
      </div>
      <div class=\"password-strength-text\"></div>
      <div class=\"password-requirements\">
        <p class=\"password-requirements-length\" data-translation=\"{{ ('Enter a password between %d and %d characters'|trans({}, 'Admin.Advparameters.Feature'))|escape('html_attr') }}\">
          <i class=\"material-icons\">check_circle</i>
          <span></span>
        </p>
        <p class=\"password-requirements-score\" data-translation=\"{{ ('The minimum score must be: %s'|trans({}, 'Admin.Advparameters.Feature'))|escape('html_attr') }}\">
          <i class=\"material-icons\">check_circle</i>
          <span></span>
        </p>
      </div>
    </div>
  </template>
{% endblock %}
", "@PrestaShop/Admin/Helpers/password_feedback.html.twig", "/var/www/html/src/PrestaShopBundle/Resources/views/Admin/Helpers/password_feedback.html.twig");
    }
}
