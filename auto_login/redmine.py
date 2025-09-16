import os
import re
from playwright.sync_api import Playwright, sync_playwright, expect


def run_admin(playwright: Playwright,config) -> None:
    browser = playwright.chromium.launch(headless=False)
    context = browser.new_context()
    page = context.new_page()
    page.goto("http://localhost:8081/login")
    page.get_by_label("Login").click()
    page.get_by_label("Login").fill("admin")
    page.get_by_label("Password Lost password").click()
    page.get_by_label("Password Lost password").fill("admin123")
    page.get_by_label("Password Lost password").press("Enter")
    page.wait_for_timeout(3000)

    config.homepages['Admin'] = page.url
    page.wait_for_load_state()
    page.context.storage_state(path=f"{folder_name}/Admin.json")

    # ---------------------
    context.close()
    browser.close()

def run_Anonymous(playwright: Playwright,config) -> None:
    browser = playwright.chromium.launch(headless=False)
    context = browser.new_context()
    page = context.new_page()

    page.goto("http://localhost:8081/")
    page.wait_for_timeout(3000)

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
