import os
import re
from playwright.sync_api import Playwright, sync_playwright, expect

def run_admin(playwright: Playwright, config) -> None:
    browser = playwright.chromium.launch(headless=False)
    context = browser.new_context()
    page = context.new_page()
    page.goto("http://localhost:8081/wp-admin")
    page.get_by_label("Username or Email Address").click()
    page.get_by_label("Username or Email Address").fill("admin")
    page.get_by_label("Password", exact=True).click()
    page.get_by_label("Password", exact=True).fill("admin123")
    page.get_by_label("Remember Me").check()
    page.get_by_label("Remember Me").press("Enter")

    page.wait_for_timeout(5000);

    config.homepages['Admin'] = page.url
    page.context.storage_state(path=f"{folder_name}/Admin.json")

    # ---------------------
    context.close()
    browser.close()


def run_Anonymous(playwright: Playwright, config) -> None:
    browser = playwright.chromium.launch(headless=False)
    context = browser.new_context()
    page = context.new_page()
    page.goto("http://localhost:8081/")

    page.context.storage_state(path=f"{folder_name}/Anonymous.json")
    # ---------------------
    context.close()
    browser.close()

folder_name = f"../login_state/{os.path.basename(__file__)}"
folder_name = folder_name[:-3]
os.makedirs(folder_name, exist_ok=True)

def main(config):
    with sync_playwright() as playwright:
        print("RUNNING NEW AUTOMATIC LOGIN FROM ",__file__)

        run_admin(playwright,config)
        run_Anonymous(playwright,config)
