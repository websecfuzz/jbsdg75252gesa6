import os
import re
from playwright.sync_api import Playwright, sync_playwright, expect


def run_admin(playwright: Playwright) -> None:
    browser = playwright.chromium.launch(headless=False)
    context = browser.new_context()
    page = context.new_page()
    page.goto("http://localhost:8081/administrator/")
    page.get_by_label("Username").click()
    page.get_by_label("Username").fill("admin")
    page.get_by_label("Password").click()
    page.get_by_label("Password").fill("admin12345678")
    page.get_by_role("button", name="Log in").click()

    page.wait_for_load_state()
    page.context.storage_state(path=f"{folder_name}/Admin.json")

    # ---------------------
    context.close()
    browser.close()

def run_2(playwright: Playwright) -> None:
    browser = playwright.chromium.launch(headless=False)
    context = browser.new_context()
    page = context.new_page()
    page.goto("http://localhost:8081/administrator/")
    page.get_by_label("Username").click()
    page.get_by_label("Username").fill("manager")
    page.get_by_label("Password").click()
    page.get_by_label("Password").fill("manager12345678")
    page.get_by_role("button", name="Log in").click()

    page.wait_for_load_state()
    page.get_by_label("Cancel").click()

    page.context.storage_state(path=f"{folder_name}/Manager.json")
    # ---------------------
    context.close()
    browser.close()

def run_3(playwright: Playwright) -> None:
    browser = playwright.chromium.launch(headless=False)
    context = browser.new_context()
    page = context.new_page()
    page.goto("http://localhost:8081/")
    page.get_by_placeholder("Username").click()
    page.get_by_placeholder("Username").fill("author")
    page.get_by_placeholder("Password").click()
    page.get_by_placeholder("Password").fill("author12345678")
    page.get_by_label("Remember Me").check()
    page.get_by_role("button", name="Log in").click()

    page.wait_for_load_state()
    page.context.storage_state(path=f"{folder_name}/Author.json")

    # ---------------------
    context.close()
    browser.close()

def run_4(playwright: Playwright) -> None:
    browser = playwright.chromium.launch(headless=False)
    context = browser.new_context()
    page = context.new_page()
    page.goto("http://localhost:8081/")
    page.get_by_placeholder("Username").click()
    page.get_by_placeholder("Username").fill("publisher")
    page.get_by_placeholder("Password").click()
    page.get_by_placeholder("Password").fill("publisher12345678")
    page.get_by_label("Remember Me").check()
    page.get_by_role("button", name="Log in").click()

    page.wait_for_load_state()
    page.context.storage_state(path=f"{folder_name}/Publisher.json")

    # ---------------------
    context.close()
    browser.close()


def run_Anonymous(playwright: Playwright) -> None:
    browser = playwright.chromium.launch(headless=False)
    context = browser.new_context()
    page = context.new_page()
    page.goto("http://localhost:8081/")

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

