import os
import re
from playwright.sync_api import Playwright, sync_playwright, expect


def run_admin(playwright: Playwright) -> None:
    browser = playwright.chromium.launch(headless=False)
    context = browser.new_context()
    page = context.new_page()
    page.goto("http://localhost:8081/app/web/en/user/login")
    page.get_by_label("Username").click()
    page.get_by_label("Username").fill("admin")
    page.get_by_label("Password").click()
    page.get_by_label("Password").fill("admin12345678")
    page.get_by_label("Password").press("Enter")

    page.wait_for_load_state()
    page.context.storage_state(path=f"{folder_name}/Admin.json")

    # ---------------------
    context.close()
    browser.close()

def run_2(playwright: Playwright) -> None:
    browser = playwright.chromium.launch(headless=False)
    context = browser.new_context()
    page = context.new_page()
    page.goto("http://localhost:8081/app/web/en/user/login")
    page.get_by_label("Username").click()
    page.get_by_label("Username").fill("author")
    page.get_by_label("Password").click()
    page.get_by_label("Password").fill("author12345678")
    page.get_by_label("Password").press("Enter")

    page.wait_for_load_state()
    page.context.storage_state(path=f"{folder_name}/Author.json")
    # ---------------------
    context.close()
    browser.close()

def run_3(playwright: Playwright) -> None:
    browser = playwright.chromium.launch(headless=False)
    context = browser.new_context()
    page = context.new_page()
    page.goto("http://localhost:8081/app/web/en/user/login")
    page.get_by_label("Username").click()
    page.get_by_label("Username").fill("editor")
    page.get_by_label("Password").click()
    page.get_by_label("Password").fill("editor12345678")
    page.get_by_label("Password").press("Enter")

    page.wait_for_load_state()
    page.context.storage_state(path=f"{folder_name}/Editor.json")

    # ---------------------
    context.close()
    browser.close()

def run_Anonymous(playwright: Playwright) -> None:
    browser = playwright.chromium.launch(headless=False)
    context = browser.new_context()
    page = context.new_page()
    page.goto("http://localhost:8081/app/web")

    page.wait_for_load_state()
    page.context.storage_state(path=f"{folder_name}/Anonymous.json")
    # ---------------------
    context.close()
    browser.close()

folder_name = f"../login_state/{os.path.basename(__file__)}"
folder_name = folder_name[:-3]
os.makedirs(folder_name, exist_ok=True)

with sync_playwright() as playwright:
    print("RUNNING AUTOMATIC LOGIN FROM ",__file__)

    run_admin(playwright)
    run_Anonymous(playwright)

