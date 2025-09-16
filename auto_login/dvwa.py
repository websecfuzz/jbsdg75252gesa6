import os
import re
from playwright.sync_api import Playwright, sync_playwright, expect


def run_admin(playwright: Playwright, config) -> None:
    browser = playwright.chromium.launch(headless=False)
    context = browser.new_context()
    page = context.new_page()
    page.goto("http://localhost:8081/login.php")
    page.locator("input[name=\"username\"]").click()
    page.locator("input[name=\"username\"]").fill("admin")
    page.locator("input[name=\"password\"]").click()
    page.locator("input[name=\"password\"]").fill("password")
    page.locator("input[name=\"password\"]").press("Enter")

    page.wait_for_timeout(2000);
    page.get_by_role("link", name="DVWA Security").click()
    page.get_by_role("combobox").select_option("low")
    page.get_by_role("button", name="Submit").click()
    page.wait_for_timeout(2000);

    config.homepages['Admin'] = page.url
    page.context.storage_state(path=f"{folder_name}/Admin.json")

    # ---------------------
    context.close()
    browser.close()

def run_admin2(playwright: Playwright, config) -> None:
    browser = playwright.chromium.launch(headless=False)
    context = browser.new_context()
    page = context.new_page()
    page.goto("http://localhost:8081/login.php")
    page.locator("input[name=\"username\"]").click()
    page.locator("input[name=\"username\"]").fill("gordonb")
    page.locator("input[name=\"password\"]").click()
    page.locator("input[name=\"password\"]").fill("abc123")
    page.locator("input[name=\"password\"]").press("Enter")

    page.wait_for_timeout(2000);
    page.get_by_role("link", name="DVWA Security").click()
    page.get_by_role("combobox").select_option("low")
    page.get_by_role("button", name="Submit").click()
    page.wait_for_timeout(2000);

    config.homepages['StandardUser'] = page.url
    page.context.storage_state(path=f"{folder_name}/StandardUser.json")

    # ---------------------
    context.close()
    browser.close()

def run_Anonymous(playwright: Playwright, config) -> None:
    browser = playwright.chromium.launch(headless=False)
    context = browser.new_context()
    page = context.new_page()
    page.goto("http://localhost:8081/login.php")

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
        run_admin2(playwright,config)
        run_Anonymous(playwright,config)
