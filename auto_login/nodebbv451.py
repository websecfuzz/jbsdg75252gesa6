import os
import re
from playwright.sync_api import Playwright, sync_playwright, expect


def run_installer(playwright: Playwright,config) -> None:
    browser = playwright.chromium.launch(headless=False)
    context = browser.new_context()
    page = context.new_page()
    page.goto("http://localhost:4567/")
    page.get_by_placeholder("Username").click()
    page.get_by_placeholder("Username").fill("admin")
    page.get_by_placeholder("Email Address").click()
    page.get_by_placeholder("Email Address").fill("admin@local.co")
    page.get_by_placeholder("Password", exact=True).click()
    page.get_by_placeholder("Password", exact=True).fill("admin123")
    page.get_by_placeholder("Confirm Password").click()
    page.get_by_placeholder("Confirm Password").fill("admin123")
    page.get_by_label("Database Type").select_option("postgres")
    page.get_by_label("Host IP or address of your PostgreSQL instance").click()
    page.get_by_label("Host IP or address of your PostgreSQL instance").fill("dbproxy")
    page.get_by_role("button", name="Install NodeBB").click()
    page.wait_for_timeout(40000)
#    page.goto("http://localhost:4567/login?local=1")

    config.homepages['Install'] = page.url
    page.wait_for_load_state()
    page.context.storage_state(path=f"{folder_name}/Install.json")

    # ---------------------
    context.close()
    browser.close()

def run_admin(playwright: Playwright,config) -> None:
    browser = playwright.chromium.launch(headless=False)
    context = browser.new_context()
    page = context.new_page()
    page.goto("http://localhost:4567/login?local=1")
    page.get_by_placeholder("Username / Email").click()
    page.get_by_placeholder("Username / Email").fill("admin")
    page.get_by_placeholder("Password").click()
    page.get_by_placeholder("Password").fill("admin123")
    page.get_by_placeholder("Password").press("Enter")

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

    page.goto("http://localhost:4567/")

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

        run_installer(playwright,config)
        run_admin(playwright,config)
        run_Anonymous(playwright,config)
