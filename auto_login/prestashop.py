import os
import re
from playwright.sync_api import Playwright, sync_playwright, expect


def run_admin(playwright: Playwright, config) -> None:
    browser = playwright.chromium.launch(headless=False)
    context = browser.new_context()
    page = context.new_page()
    page.goto("http://localhost:8081/admin9671czlrok7qbdn2pre/")
    page.get_by_role("textbox", name="Email address").click()
    page.get_by_role("textbox", name="Email address").fill("admin@local.co")
    page.get_by_placeholder(" Password").click()
    page.get_by_placeholder(" Password").fill("fuzzer123")
    page.get_by_label("Stay logged in").check()
    page.get_by_role("button", name="Log in").click()

    page.wait_for_timeout(5000);
    # page.locator("#header_infos #header_logo").click()

    config.homepages['Admin'] = page.url

    page.wait_for_load_state()
    page.context.storage_state(path=f"{folder_name}/Admin.json")

    # ---------------------
    context.close()
    browser.close()

def run_2(playwright: Playwright, config) -> None:
    browser = playwright.chromium.launch(headless=False)
    context = browser.new_context()
    page = context.new_page()
    page.goto("http://localhost:8081/admin9671czlrok7qbdn2pre")
    page.get_by_role("textbox", name="Email address").click()
    page.get_by_role("textbox", name="Email address").fill("logistician@local.co")
    page.get_by_placeholder(" Password").click()
    page.get_by_placeholder(" Password").fill("fuzzer123")
    page.get_by_label("Stay logged in").check()
    page.get_by_role("button", name="Log in").click()

    page.wait_for_timeout(5000);
    # page.locator("#header_infos #header_logo").click()

    config.homepages['Logistician'] = page.url

    page.wait_for_load_state()
    page.context.storage_state(path=f"{folder_name}/Logistician.json")
    # ---------------------
    context.close()
    browser.close()

def run_3(playwright: Playwright, config) -> None:
    browser = playwright.chromium.launch(headless=False)
    context = browser.new_context()
    page = context.new_page()
    page.goto("http://localhost:8081/admin9671czlrok7qbdn2pre")
    page.get_by_role("textbox", name="Email address").click()
    page.get_by_role("textbox", name="Email address").fill("translator@local.co")
    page.get_by_placeholder(" Password").click()
    page.get_by_placeholder(" Password").fill("fuzzer123")
    page.get_by_label("Stay logged in").check()
    page.get_by_role("button", name="Log in").click()

    page.wait_for_timeout(5000);
    # page.locator("#header_infos #header_logo").click()

    config.homepages['Translator'] = page.url

    page.wait_for_load_state()
    page.context.storage_state(path=f"{folder_name}/Translator.json")
    # ---------------------
    context.close()
    browser.close()

def run_4(playwright: Playwright, config) -> None:
    browser = playwright.chromium.launch(headless=False)
    context = browser.new_context()
    page = context.new_page()

    page.goto("http://localhost:8081/admin9671czlrok7qbdn2pre")
    page.get_by_role("textbox", name="Email address").click()
    page.get_by_role("textbox", name="Email address").fill("salesman@local.co")
    page.get_by_placeholder(" Password").click()
    page.get_by_placeholder(" Password").fill("fuzzer123")
    page.get_by_label("Stay logged in").check()
    page.get_by_role("button", name="Log in").click()

    page.wait_for_timeout(5000);
    # page.locator("#header_infos #header_logo").click()

    config.homepages['Salesman'] = page.url

    page.wait_for_load_state()
    page.context.storage_state(path=f"{folder_name}/Salesman.json")
    # ---------------------
    context.close()
    browser.close()

def run_5(playwright: Playwright, config) -> None:
    browser = playwright.chromium.launch(headless=False)
    context = browser.new_context()
    page = context.new_page()
    page.goto("http://localhost:8081/")
    page.get_by_role("link", name=" Sign in").click()
    page.get_by_label("Email").click()
    page.get_by_label("Email").fill("customer@local.co")
    page.get_by_label("Password input").click()
    page.get_by_label("Password input").fill("fuzzer123")
    page.get_by_role("button", name="Sign in").click()

    page.wait_for_timeout(3000);
    # page.get_by_role("link", name="WUT").click()

    config.homepages['Customer'] = page.url

    page.wait_for_load_state()
    page.context.storage_state(path=f"{folder_name}/Customer.json")
    # ---------------------
    context.close()
    browser.close()

def run_Anonymous(playwright: Playwright, config) -> None:
    browser = playwright.chromium.launch(headless=False)
    context = browser.new_context()
    page = context.new_page()

    page.goto("http://localhost:8081")
    config.homepages['Anonymous'] = page.url

    page.wait_for_load_state()
    page.context.storage_state(path=f"{folder_name}/Anonymous.json")
    # ---------------------
    context.close()
    browser.close()

folder_name = f"../login_state/{os.path.basename(__file__)}"
folder_name = folder_name[:-3]
os.makedirs(folder_name, exist_ok=True)

def main(config):
    with sync_playwright() as playwright:
        print("RUNNING AUTOMATIC LOGIN FROM ",__file__)

        run_admin(playwright,config)
        run_Anonymous(playwright,config)
