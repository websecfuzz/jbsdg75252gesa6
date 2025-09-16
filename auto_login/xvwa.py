import os
import re
from playwright.sync_api import Playwright, sync_playwright, expect


def run_admin(playwright: Playwright) -> None:
    browser = playwright.chromium.launch(headless=False)
    context = browser.new_context()
    page = context.new_page()
    page.goto("http://localhost:8081/xvwa/")
    page.get_by_role("link", name="Setup / Reset").click()
    page.get_by_role("button", name="Submit / Reset").click()
    page.get_by_role("link", name="Login").click()
    page.get_by_placeholder("Username").click()
    page.get_by_placeholder("Username").fill("admin")
    page.get_by_placeholder("Password").click()
    page.get_by_placeholder("Password").fill("admin")
    page.get_by_role("button", name="Login").click()
    page.wait_for_timeout(3000)

    page.context.storage_state(path=f"{folder_name}/Admin.json")

    # ---------------------
    context.close()
    browser.close()

def run_StandardUser(playwright: Playwright) -> None:
    browser = playwright.chromium.launch(headless=False)
    context = browser.new_context()
    page = context.new_page()
    page.goto("http://localhost:8081/xvwa/")
    page.get_by_role("link", name="Login").click()
    page.get_by_placeholder("Username").click()
    page.get_by_placeholder("Username").fill("xvwa")
    page.get_by_placeholder("Password").click()
    page.get_by_placeholder("Password").fill("xvwa")
    page.get_by_role("button", name="Login").click()
    page.wait_for_timeout(3000)

    page.context.storage_state(path=f"{folder_name}/StandardUser.json")
    # ---------------------
    context.close()
    browser.close()

def run_Anonymous(playwright: Playwright) -> None:
    browser = playwright.chromium.launch(headless=False)
    context = browser.new_context()
    page = context.new_page()
    page.goto("http://localhost:8081/xvwa/")

    page.context.storage_state(path=f"{folder_name}/Anonymous.json")
    # ---------------------
    context.close()
    browser.close()

folder_name = f"../login_state/{os.path.basename(__file__)}"
folder_name = folder_name[:-3]
# print(folder_name)
os.makedirs(folder_name, exist_ok=True)

with sync_playwright() as playwright:
    print("RUNNING AUTOMATIC LOGIN FROM ",__file__)

    run_admin(playwright)
    run_StandardUser(playwright)
    run_Anonymous(playwright)

