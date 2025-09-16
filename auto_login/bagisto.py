import os
import re
from playwright.sync_api import Playwright, sync_playwright, expect


def run_admin(playwright: Playwright,config) -> None:
    browser = playwright.chromium.launch(headless=False)
    context = browser.new_context()
    page = context.new_page()
    page.goto("http://localhost:8081/admin/login")
    page.get_by_placeholder("Email Address").click()
    page.get_by_placeholder("Email Address").fill("admin@example.com")
    page.get_by_placeholder("Email Address").press("Tab")
    page.get_by_placeholder("Password").fill("admin123")
    page.get_by_label("Sign In").click()
    page.get_by_role("link", name=" Dashboard").click()

    config.homepages['Admin'] = page.url
    page.wait_for_load_state()
    page.context.storage_state(path=f"{folder_name}/Admin.json")

    # ---------------------
    context.close()
    browser.close()

def run_2(playwright: Playwright,config) -> None:
    browser = playwright.chromium.launch(headless=False)
    context = browser.new_context()
    page = context.new_page()
    page.goto("http://localhost:8081/public/admin/login")
    page.get_by_placeholder("Email Address").click()
    page.get_by_placeholder("Email Address").fill("marketing@example.com")
    page.get_by_placeholder("Email Address").press("Tab")
    page.get_by_placeholder("Password").fill("marketing123")
    page.get_by_label("Sign In").click()

    page.goto("http://localhost:8081/public/")

    config.homepages['Marketing'] = page.url
    page.wait_for_load_state()
    page.context.storage_state(path=f"{folder_name}/Marketing.json")
    # ---------------------
    context.close()
    browser.close()

def run_3(playwright: Playwright,config) -> None:
    browser = playwright.chromium.launch(headless=False)
    context = browser.new_context()
    page = context.new_page()
    page.goto("http://localhost:8081/public/customer/login")
    page.get_by_placeholder("email@example.com").click()
    page.get_by_placeholder("email@example.com").fill("gencustomer@example.com")
    page.get_by_placeholder("email@example.com").press("Tab")
    page.get_by_placeholder("Password").click()
    page.get_by_placeholder("Password").fill("customer123")
    page.get_by_role("button", name="Sign In").click()
    page.get_by_role("link", name="Bagisto").click()

    config.homepages['GenCustomer'] = page.url
    page.wait_for_load_state()
    page.context.storage_state(path=f"{folder_name}/GenCustomer.json")
    # ---------------------
    context.close()
    browser.close()

def run_4(playwright: Playwright,config) -> None:
    browser = playwright.chromium.launch(headless=False)
    context = browser.new_context()
    page = context.new_page()
    page.goto("http://localhost:8081/public/customer/login")
    page.get_by_placeholder("email@example.com").click()
    page.get_by_placeholder("email@example.com").fill("wholesale@example.com")
    page.get_by_placeholder("email@example.com").press("Tab")
    page.get_by_placeholder("Password").click()
    page.get_by_placeholder("Password").fill("wholesale123")
    page.get_by_role("button", name="Sign In").click()
    page.get_by_role("link", name="Bagisto").click()

    config.homepages['WholeSale'] = page.url
    page.wait_for_load_state()
    page.context.storage_state(path=f"{folder_name}/WholeSale.json")
    # ---------------------
    context.close()
    browser.close()

def run_5(playwright: Playwright,config) -> None:
    browser = playwright.chromium.launch(headless=False)
    context = browser.new_context()
    page = context.new_page()
    page.goto("http://localhost:8081/public/customer/login")
    page.get_by_placeholder("email@example.com").click()
    page.get_by_placeholder("email@example.com").fill("guest@example.com")
    page.get_by_placeholder("email@example.com").press("Tab")
    page.get_by_placeholder("Password").click()
    page.get_by_placeholder("Password").fill("guest123")
    page.get_by_role("button", name="Sign In").click()
    page.get_by_role("link", name="Bagisto").click()

    config.homepages['Guest'] = page.url
    page.wait_for_load_state()
    page.context.storage_state(path=f"{folder_name}/Guest.json")
    # ---------------------
    context.close()
    browser.close()

def run_Anonymous(playwright: Playwright,config) -> None:
    browser = playwright.chromium.launch(headless=False)
    context = browser.new_context()
    page = context.new_page()

    page.goto("http://localhost:8081/")

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
