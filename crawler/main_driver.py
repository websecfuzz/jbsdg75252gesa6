import csv
import os
import random
import logging
import re
import traceback
from datetime import datetime
from os.path import isfile, join
from typing import List, Dict
from urllib.parse import urlparse, urljoin
from uuid import uuid4
import time
import copy

import asyncio

from playwright.sync_api import Request, Locator, Route

from config import config
from function import get_form_id, cleanhtml, extract_paramvals_from_url, save_param_value_to_dict, \
    delete_files, get_query_keys, get_stdr_url_from_page
from Dictionary import dictionary
from GlobalAttackSurfaces import global_attack_surfaces
from AttackSurface import AttackSurface
#from AICaller import build_param_filtering_prompt, AICaller
from general_functions import is_same_domain, randomword, \
    get_absolute_link, read_cov_from_file

from HTTPRequest import convert_request_type, HTTPRequest, \
    convert_request_to_yaml, convert_yaml_file_to_request

class MainDriver:
    """
    This class will crawl and intercept HTTP requests from the highest-role user pages.
    """
    def __init__(self, role=None):
        self.start_time = datetime.now()
        self.role = role
        self.page = None
        self.browser = None
        self.context = None
        self.corpus_length = 0
        self.corpus : List[HTTPRequest] = list()
        self.logger = logging.getLogger()
        self.link_to_crawl = list()
        self.idx_priority_links = list()
        self.last_process_link_idx = -1
        self.specific_target_keywords = list()
        self.active_checker = None
        self.forms = list()
        self.clicked_link_names = list()
        self.clicked_buttons = list()
        self.is_clicked_buttons = False
        self.trigger = None
        self.current_url = None
        self.is_crawling_complete = True
        self.is_back_request = False

        ## ---
        self.visited = set()
        self.base_url = None
        self.parsed_url = dict()
        self.MAX_SAME_URL = 15
        self.new_tabs = list()
        self.current_tabs = 0
        self.select_form_ids = list()

        self.reqs_to_be_expanded = list()
        self.results = list()

    def is_containing_specific_target_keywords(self, url: str):
        if len(self.specific_target_keywords)>0:
            for key in self.specific_target_keywords:
                if url.find(key)>-1:
                    return True
            return False
        else:
            return True

    def is_avoided_links(self, txt, url: str):
        for key in config.data["AVOIDED_LINKS"]:
            if txt.lower().find(key)>-1 or url.find(key)>-1:
                print(f"[MAINDRIVER {self.role}] {txt}[{url}] is an avoided links! Drop it.")
                return True
        return False

    def is_avoided_action(self, req):
        avoided_actions = ["delete"]
        atomic_paramvals = req.get_all_atomic_param_vals()
        atomic_values = [p.value for p in atomic_paramvals]
        for key in avoided_actions:
            if key in atomic_values or req.full_url.find(key)>-1:
                print(f"[MAINDRIVER {self.role}] {req} is an avoided request! Drop it.")
                return True
        return False

    async def start_with_login_state(self, playwright, storage_state):
        """
        We assume the user is logged-in, in which the logged-in data was stored in the storage_state
        :param playwright:
        :return:
        """
        print(f"[MAINDRIVER {self.role}] ----STARTING MAIN DRIVER-----")
        print(f"[MAINDRIVER {self.role}] Login state: {storage_state}")
        self.browser = await playwright.chromium.launch(headless=False)
        if config.proxy:
            self.context = await self.browser.new_context(storage_state=storage_state, proxy={"server": config.proxy})
        else:
            self.context = await self.browser.new_context(storage_state=storage_state)
        self.page = await self.context.new_page()

    async def filling_a_form(self, form):
        print(f"[MAINDRIVER {self.role}] Filling a form: {form}")
        last_element = None
        must_be_same_value = None
        input_elements = await form.locator('input, textarea').all()
        for input_element in input_elements:
            try:
                name: str = await input_element.get_attribute("name")
                input_type = await input_element.get_attribute("type")
                print(f"[MAINDRIVER {self.role}] {name} with type of {input_type} is identified")
                if (await input_element.is_visible() and await input_element.is_enabled() and await input_element.is_editable()):
                    if (input_type and input_type=="email") or (name and name.find("email")>-1):
                        print(f"[MAINDRIVER {self.role}] Filling email for", name, " in the form")
                        await input_element.fill(randomword(5)+config.data["UNIQUE_STRING"]+"@yahoo.com")
                    elif (input_type and input_type=="url"):
                        print(f"[MAINDRIVER {self.role}] Filling url for", name, " in the form")
                        await input_element.fill(randomword(5)+config.data["UNIQUE_STRING"]+".com")
                    elif (input_type and input_type=="number"):
                        print(f"[MAINDRIVER {self.role}] Filling number for", name, " in the form")
                        await input_element.fill(str(config.data["UNIQUE_NUMBER"]))
                    elif input_type and (input_type == 'checkbox' or input_type == 'radio'):
                        print(f"[MAINDRIVER {self.role}] Checking a {input_type} for", name, " in the form")
                        await input_element.check()
                    elif (input_type and input_type=="password"):
                        if must_be_same_value == None:
                            txt = randomword(5)+config.data["UNIQUE_STRING"]
                            must_be_same_value = txt

                        print(f"[MAINDRIVER {self.role}] Filling password for", name, "in the form with", must_be_same_value)
                        await input_element.fill(must_be_same_value)
                    elif (input_type and input_type=="submit"):
                        print(f"[MAINDRIVER {self.role}] Found a submit button {input_element}. Click it.")
                        await input_element.click()
                    elif (input_type and input_type=="file"):
                        print(f"[MAINDRIVER {self.role}] Found a file button {input_element}. Fill it with a file.")
                        await input_element.set_input_files("free.jpg")
                    else:
                        txt = randomword(5)+config.data["UNIQUE_STRING"]
                        print(f"[MAINDRIVER {self.role}] Filling text for", name, "in the form with",txt)
                        await input_element.fill(txt)
                    last_element = input_element
                else:
                    print(input_element, "is not visible or enabled or editable")
            except Exception as e:
                print(f"[MAINDRIVER {self.role}] Error in filling ", input_element)
                print(f"[MAINDRIVER {self.role}] {str(e)[-100:]}")
                print(f"[MAINDRIVER {self.role}] {traceback.format_exc()[-1000:]}")
                data_title = f"../data/input-{randomword(10)}.jpeg"
                await self.page.screenshot(path=data_title)
                print(f"[MAINDRIVER {self.role}] Saving the error screenshot in {data_title}")

        select_elements = await form.get_by_role("listbox ").all() + await form.get_by_role("combobox ").all()
        print(f"[MAINDRIVER {self.role}] Identifying {len(select_elements)} select elements in the form. Start to iterate")
        for select_element in select_elements:
            name: str = await select_element.get_attribute("name")
            input_type = await select_element.get_attribute("type")
            print(f"[MAINDRIVER {self.role}] {name} with type of {input_type} is identified")

            select_form_id = str(name) + str(await form.get_attribute("name"))
            if select_form_id in self.select_form_ids:
                print(f"[MAINDRIVER {self.role}] {name} with type of {input_type} has been processed before. Skip it.")
                continue
            else:
                print(f"[MAINDRIVER {self.role}] {name} with type of {input_type} is new. Process it.")
                self.select_form_ids.append(select_form_id)

            if (await select_element.is_visible() and await select_element.is_enabled() and await select_element.is_editable()):
                try:
                    options = await select_element.get_by_role("option").all()
                    print(f"[MAINDRIVER {self.role}] Iterate all options: {len(options)} in a select element")
                    idx = 0
                    for opt in options:
                        print(f"[MAINDRIVER {self.role}] Selecting option number {idx} --> {opt}")
                        await select_element.select_option(index=idx)
                        idx+=1

                        val_atr = await opt.get_attribute("value")
                        if val_atr==None:
                            val_atr = await opt.inner_text()
                        save_param_value_to_dict(name,val_atr,self.role)

                except Exception as e:
                    print(f"[MAINDRIVER {self.role}] Error in selecting a value from", select_element)
                    print(f"[MAINDRIVER {self.role}] {str(e)[-100:]}")
            else:
                print(f"[MAINDRIVER {self.role}] {select_element} is not visible or enabled or editable")

        return last_element

    async def fill_all_forms(self, locator, is_on_popup=False):
        forms = await locator.locator("form").all()
        print(f"[MAINDRIVER {self.role}] Identifying",len(forms),"form in locator: ",locator)
        for form in forms:
            last_element = await self.filling_a_form(form)
            if last_element:
                await last_element.press("Enter")

    async def click_all_buttons(self, locator, is_on_popup=False):
        buttons = await locator.get_by_role("button").all()
        print(f"[MAINDRIVER {self.role}] In total, finding {len(buttons)} button in {locator}")

        for button in buttons:
            try:
                button_name = await button.inner_text(timeout=2000)
                if not is_on_popup:
                    if button_name in self.clicked_buttons:
                        print(f"[MAINDRIVER {self.role}] Skip button {button_name} because it was clicked")
                        continue

                print(f"[MAINDRIVER {self.role}] Trying to click a button:", button_name)

                if (await button.is_visible() and await button.is_enabled()):
                    self.is_clicked_buttons = True

                    if not is_on_popup:
                        self.clicked_buttons.append(button_name)

                    await self.page.wait_for_timeout(1000)
                    await button.click(force=True)
                    self.trigger = button_name
                    await self.page.wait_for_timeout(1000)
            except Exception as e:
                print(f"[MAINDRIVER {self.role}] Fail to click button:", e)

            self.is_clicked_buttons = False

    async def get_model_by_role(self):
        return await self.page.get_by_role("alert").all() + await self.page.get_by_role("alertdialog").all() + await self.page.get_by_role("dialog").all()

    async def get_modals(self):
        print(f"[MAINDRIVER {self.role}] --- Processing the page {self.page.url} to find overlay modals")
        try:
            modals = await asyncio.wait_for(self.get_model_by_role(),timeout=60)
        except Exception as e:
            print(f"[MAINDRIVER {self.role}] get_modals error: {e}")
            modals = None

        if modals==None or len(modals)==0:
            print(f"[MAINDRIVER {self.role}] No overlay modal")
            return False

        for modal in modals:
            print(f"[MAINDRIVER {self.role}] Getting modal: {modal}. Trying to fill forms and click buttons there.")
            await self.fill_all_forms(modal, is_on_popup=True)
            await self.click_all_buttons(modal, is_on_popup=True)

    async def find_and_click_buttons(self, page=None):
        if page==None:
            page = self.page
        if not is_same_domain(page.url):
            print(f"[MAINDRIVER {self.role}] --- The page {page.url} is out of our search domain. Skip it from form filling")
            return None

        print(f"[MAINDRIVER {self.role}] --- Processing the page {page.url} to find and click buttons")

        button_alikes = await page.locator("a[href='#']").all() + await page.locator("a[href='javascript:void(0)']").all()

        buttons = await page.get_by_role("button").all() + button_alikes
        print(f"[MAINDRIVER {self.role}] In total, finding {len(buttons)} button in the page {page.url}")


        idx = 0
        for button in buttons:
            idx +=1
            try:
                url = get_stdr_url_from_page(page.url)
                button_name = str(await button.inner_text(timeout=2000)) + url

                try:
                    onclick = await button.get_attribute("onclick")
                    if onclick and onclick!="":
                        button_name = onclick
                except Exception as e:
                    print(f"[MAINDRIVER {self.role}] Exception on getting onclick attribute: {e}")

                if button_name in self.clicked_buttons:
                    print(f"[MAINDRIVER {self.role}] Skip button {button_name} because it was clicked")
                    continue
                print(f"[MAINDRIVER {self.role}] Trying to click a button:", button_name)

                if (await button.is_visible() and await button.is_enabled()):
                    self.is_clicked_buttons = True
                    self.clicked_buttons.append(button_name)

                    await page.wait_for_timeout(1000)
                    await button.click(force=True)
                    self.trigger = button_name
                    await page.wait_for_timeout(1000)
            except Exception as e:
                self.is_clicked_buttons = False
                print(f"[MAINDRIVER {self.role}] Fail to click button:", e)

            self.is_clicked_buttons = False
            await self.get_modals()

    async def find_and_fill_forms(self, page=None):
        if page==None:
            page = self.page
        if not is_same_domain(page.url):
            print(f"[MAINDRIVER {self.role}] --- The page {page.url} is out of our search domain. Skip it from form filling")
            return None

        print(f"[MAINDRIVER {self.role}] --- Processing the page {page.url} to find and fill forms")
        current_url = page.url
        exception=False
        try:
            forms = await page.locator("form").all()
            print(f"[MAINDRIVER {self.role}] Identifying",len(forms),"form in page: ",page.url)

            for form in forms:
                form_name = await get_form_id(form)
                if form_name==None or form_name=="" or form_name=="#":
                    print(f"[MAINDRIVER {self.role}] There is no form name. It is fine. Continue to fill in")
                elif form_name in self.forms:
                    print(f"[MAINDRIVER {self.role}] {form_name} is already executed before. Skip it")
                    continue
                else:
                    self.forms.append(form_name)

                last_element = None
                button_names = list()
                buttons = await form.get_by_role("button").all()
                print(f"[MAINDRIVER {self.role}] Finding {len(buttons)} button in the page {page.url}")

                if len(buttons)>0:
                    for button in buttons:
                        button_name = await button.inner_text(timeout=2000)
                        if button_name in button_names:
                            print(f"[MAINDRIVER {self.role}] NOT Process the button:", button_name, "because it is the same like the previous one")
                            continue

                        last_element = await self.filling_a_form(form)
                        e_message = None

                        print(f"[MAINDRIVER {self.role}] Trying to click a button:", button_name)
                        fail = False
                        try:
                            if (await button.is_visible() and await button.is_enabled()):
                                button_names.append(button_name)
                                self.clicked_buttons.append(button_name)

                                await page.wait_for_timeout(1000)
                                await button.click(force=True)
                                self.trigger = button_name
                                await page.wait_for_timeout(1000)
                            else:
                                fail = True
                        except Exception as e:
                            fail = True
                            e_message = str(e)

                        if fail:
                            data_title = f"../data/button-{randomword(10)}.jpeg"
                            await page.screenshot(path=data_title)
                            print(f"[MAINDRIVER {self.role}] Button is not in the viewport! Clicking action is failed")
                            print(f"[MAINDRIVER {self.role}] Saving the screenshot in {data_title}")
                            print(f"[MAINDRIVER {self.role}] {str(e_message)[-100:]}")
                            try:
                                await button.dispatch_event('click')
                            except Exception as e:
                                print(f"[MAINDRIVER {self.role}] {str(e)[-100:]}")
                else:
                    last_element = await self.filling_a_form(form)

                if last_element:
                    await last_element.press("Enter")

        except Exception as e:
            exception = True
            print(f"[MAINDRIVER {self.role}] Error to locate element: ", e)

        if exception:
            try:
                exception = False
                data_title = f"../data/form-{randomword(10)}.jpeg"
                await self.page.screenshot(path=data_title)
            except Exception as e:
                print(f"[MAINDRIVER {self.role}] Error page.screenshot:", e)

        if forms and len(forms)<1:
            print(f"[MAINDRIVER {self.role}] No Editable Form is found")


    async def press_enter_on_element(self, locator: Locator):
        print(f"[MAINDRIVER {self.role}] Pressing enter on:",locator)
        try:
            await locator.press("Enter")
        except Exception as e:
            print(f"[MAINDRIVER {self.role}] {str(e)[-100:]}")

    def is_avoided_request(self, request: Request):
        for avoided in config.data["AVOIDED_REQUEST_POST_DATA"]:
            if request.post_data and request.post_data.find(avoided)>-1:
                return True
        return False

    def save_to_global_attack_surfaces(self, request: HTTPRequest):
        print(f"[MAINDRIVER {self.role}] Save it to Global Attack Surface")
        attack = AttackSurface(request)
        global_attack_surfaces.add(attack, self.role)

    async def go_back(self, request):
        print(f"[MAINDRIVER {self.role}] GO BACK!")
        fail = False
        try:
            await self.page.go_back()
        except Exception as e:
            fail = True

        if fail:
            if "referer" in request.headers:
                print(f"[MAINDRIVER {self.role}] GO BACK using referer to {request.headers['referer']}")
                await self.page.goto(request.headers['referer'])
            else:
                print(f"[MAINDRIVER {self.role}] GO BACK to the homepage: {config.data['HOMEPAGE_URL']}")
                await self.page.goto(config.data["HOMEPAGE_URL"])
            await self.page.wait_for_load_state()

    def is_url_to_crawl(self, full_url):
        print(f"[MAINDRIVER {self.role}] Checking if the {full_url} is in the crawled list")
        for link in self.link_to_crawl:
            if link['href'] == full_url:
                return True
        return False

    async def save_to_corpus(self, request: Request, is_save_to_file=True):
        ## CONVERT AND DROP THE COOKIE HEADER
        trigger = self.trigger
        req = await convert_request_type(request, role=self.role)
        if self.is_url_to_crawl(req.full_url) or req not in self.corpus:
            req.trigger = trigger
            self.corpus.append(req)
            print(f"[MAINDRIVER {self.role}] Save a new request to Corpus", req)
            print(f"[MAINDRIVER {self.role}] Corpus length:", len(self.corpus))

            self.save_to_global_attack_surfaces(req)

            self.corpus_length = len(self.corpus)
            if is_save_to_file:
                self.store_request_to_file_as_attack_surface(req)

            if self.active_checker:
                save_task = asyncio.create_task(self.active_checker.save_to_attack_surface_and_check(req))
                await save_task

            if req.is_HTML_form:
                print(f"[MAINDRIVER {self.role}] Mark the request to be expanded later")
                self.reqs_to_be_expanded.append(req)
        else:
            print(f"[MAINDRIVER {self.role}] Drop the request because it already exists in Corpus", req)

        return req

    async def mock_route(self, route: Route):
        await route.abort()

    async def new_abort_req_and_save_to_corpus(self, route: Route):
        self.current_url = self.page.url
        request = route.request
        headers = request.headers.copy()
        headers['X-REQUEST-ID'] = str(int(time.time())) + "-" + str(uuid4())
        
        if (is_same_domain(request.url)):
            if (request.resource_type=="script" or request.resource_type=="stylesheet" or request.resource_type=="image" or request.resource_type=="font" or request.resource_type=="media"):
                await route.continue_(headers=headers)
            elif request.url.find(".js?")>-1:
                print(f"[MAINDRIVER {self.role}] Skipping the Javascript URL of {request.url}")
                await route.continue_(headers=headers)
            else:
                if self.is_avoided_links("TXT",request.url):
                    print(f"[MAINDRIVER {self.role}] Abort the request because it is avoided string: {request.url}")
                    await self.mock_route(route)
                else:
                    if "referer" in request.headers:
                        print(f"[MAINDRIVER {self.role}] ---INTERCEPTING REQUEST FROM: {request.headers['referer']} ---")
                    else:
                        print(f"[MAINDRIVER {self.role}] ---INTERCEPTING REQUEST---")

                    req = await self.save_to_corpus(request)

                    if not self.is_back_request and self.is_avoided_action(req):
                        print(f"[MAINDRIVER {self.role}] Getting an avoided_action. Try to cancel")
                        await self.mock_route(route)
                        self.is_back_request = True
                        await self.page.goto(self.current_url)
                        await self.page.wait_for_load_state('domcontentloaded')
                    else:
                        if request.is_navigation_request():
                            await route.continue_(headers=headers)
                            self.is_back_request = False
                        else:
                            await route.continue_(headers=headers)

                    print(f"[MAINDRIVER {self.role}] ----END OF INTERCEPTION {request.method} {request.url}----")
        else:
            await route.continue_(headers=headers)


    async def get_visible_text_from_link(self, link):
        raw_txt = await link.inner_text()
        if raw_txt and raw_txt!="":
            clean_txt = re.sub(r'\W+', '', raw_txt)
            return clean_txt

        raw_html = await link.inner_html()
        if raw_html and raw_html!="":
            clean_html = cleanhtml(raw_html)
            clean_txt_2 = re.sub(r'\W+', '', clean_html)
            return clean_txt_2

        data_tip = await link.get_attribute("data-tip")
        if data_tip:
            return data_tip

        print(f"[MAINDRIVER {self.role}] No visible text is found from {await link.inner_html()}")
        return raw_txt

    def save_link(self, full_link):
        par_url = self.parse_url(full_link)
        is_new_link, idx = self.is_new_link(full_link, par_url, txt=None)
        if is_new_link:
            formatted_link = {}
            formatted_link['text'] = "NewTab"
            formatted_link['href'] = full_link
            formatted_link['par_url'] = par_url
            formatted_link['num_found'] = 1
            formatted_link['is_visited'] = False
            formatted_link['idx'] = len(self.link_to_crawl)
            formatted_link['source'] = self.page.url
            formatted_link['num_click'] = 0

            self.idx_priority_links.append(formatted_link['idx'])
            self.link_to_crawl.append(formatted_link)
            print(f"[MAINDRIVER {self.role}] A new link is found and added: {full_link}")

            url1 = f"{par_url.scheme}://{par_url.netloc}{par_url.path}?"
            query_keys1 = get_query_keys(full_link)
            separator = ","
            url_query1 = url1+separator.join(query_keys1)
            formatted_link['url_query'] = url_query1

            if url_query1 in self.parsed_url:
                self.parsed_url[url_query1] += 1
            else:
                self.parsed_url[url_query1] = 1
            print(f"[MAINDRIVER {self.role}] parsed_url add {url_query1} count: {self.parsed_url[url_query1]}")
        else:
            self.link_to_crawl[idx]['num_found'] += 1
            if idx in self.idx_priority_links:
                self.idx_priority_links.remove(idx)

        extract_paramvals_from_url(full_link,self.role)

    async def get_crawled_links(self, page=None):
        if page==None:
            page = self.page
        print(f"[MAINDRIVER {self.role}] --- GETTING CRAWLED LINKS FROM {page.url} ---")

        if not is_same_domain(page.url):
            print(f"[MAINDRIVER {self.role}] --- The page {page.url} is out of our search domain. Skip it from crawling")
            return None

        try:
            await page.wait_for_selector("a", timeout=30000)
        except:
            print(f"[MAINDRIVER {self.role}] No <a> tag is found in {page.url}")

        current_links = await page.get_by_role("link", include_hidden=True).all()

        for link in current_links:
            href = await link.get_attribute('href')
            txt = await self.get_visible_text_from_link(link)
            full_link = get_absolute_link(href,page.url)
            if (href and href[0]=='#') or (not full_link.startswith('http')):

                continue

            if is_same_domain(href) and not self.is_avoided_links(txt,href):
                par_url = self.parse_url(full_link)
                is_new_link, idx = self.is_new_link(full_link, par_url, txt)
                if is_new_link:
                    formatted_link = {}
                    formatted_link['locator'] = link
                    formatted_link['text'] = txt
                    formatted_link['href'] = full_link
                    formatted_link['par_url'] = par_url
                    formatted_link['num_found'] = 1
                    formatted_link['is_visited'] = False
                    formatted_link['idx'] = len(self.link_to_crawl)
                    formatted_link['source'] = page.url
                    formatted_link['num_click'] = 0

                    self.idx_priority_links.append(formatted_link['idx'])
                    self.link_to_crawl.append(formatted_link)
                    print(f"[MAINDRIVER {self.role}] A new link is found and added: [{txt}] --> {href}")

                    url1 = f"{par_url.scheme}://{par_url.netloc}{par_url.path}?"
                    query_keys1 = get_query_keys(full_link)
                    separator = ","
                    url_query1 = url1+separator.join(query_keys1)
                    formatted_link['url_query'] = url_query1

                    if url_query1 in self.parsed_url:
                        self.parsed_url[url_query1] += 1
                    else:
                        self.parsed_url[url_query1] = 1

                    print(f"[MAINDRIVER {self.role}] parsed_url add {url_query1} count: {self.parsed_url[url_query1]}")
                else:
                    self.link_to_crawl[idx]['num_found'] += 1
                    if idx in self.idx_priority_links:
                        self.idx_priority_links.remove(idx)

                extract_paramvals_from_url(full_link,self.role)

        print(f"[MAINDRIVER {self.role}] Total links stored:",len(self.link_to_crawl))

    def is_new_link(self, full_link, par_url, txt):
        idx = 0
        for d in self.link_to_crawl:
            if self.is_same_parsedurl(d, full_link, par_url, txt):
                print(f"[MAINDRIVER {self.role}] Link: [{txt}] {full_link} is dropped because it existed")
                return False, idx
            idx +=1
        return True, 0

    def parse_url(self, url):
        return urlparse(url)

    def is_same_parsedurl(self, formatted_link1, full_link2, parsed_url2, txt2):
        ## Compare the visible text, the url without the fragment, and the query fields only without the values
        ## PARSE TO <scheme>://<netloc>/<path>;<params>?<query>#<fragment>

        ## if the full link is completely the same with any existing links, it is true
        if full_link2.startswith('http') and formatted_link1['href']==full_link2:
            return True

        ## For example: http://localhost:8083/wp-admin/admin.php?page=wc-reports&tab=orders&range=custom&start_date=okevpzap&end_date=oosczzap&wc_reports_nonce=0d9c66c5c3&range=custom&start_date=okevpzap&end_date=oosczzap&wc_reports_nonce=0d9c66c5c3
        ## the link is new, but it might has a slightly different (e.g., the query value), so we only accept MAX_SAME_URL
        url2 = f"{parsed_url2.scheme}://{parsed_url2.netloc}{parsed_url2.path}?"

        query_keys2 = get_query_keys(full_link2)

        separator = ","
        url_query1 = formatted_link1['url_query']
        url_query2 = url2+separator.join(query_keys2)

        if url_query1==url_query2:

            if url_query1 in self.parsed_url and self.parsed_url[url_query1] > self.MAX_SAME_URL:
                print(f"[MAINDRIVER {self.role}] We have many number of link: {url_query1} [{self.parsed_url[url_query1]}]")
                return True
            else:
                return False
        else:
            return False

    def is_same_parsedurl2(self, formatted_link1, full_link2, parsed_url2, txt2):
        ## Compare the visible text, the url without the fragment, and the query fields only without the values
        ## PARSE TO <scheme>://<netloc>/<path>;<params>?<query>#<fragment>
        parsed_url1 = formatted_link1['par_url']

        if full_link2.startswith('http'):
            if formatted_link1['href']==full_link2:
                return True
            else:
                return False
        else:
            if formatted_link1['text']==txt2 and formatted_link1['href']==full_link2:
                return True
            else:
                return False


    def save_crawled_link_to_txt(self, start_time):
        filename = f"{self.role}_{start_time.hour}{start_time.minute}{start_time.second}{start_time.microsecond}"
        print(f"[MAINDRIVER {self.role}] Storing the crawled links to: ../result/{filename}.txt")
        with open(f"../result/{filename}.txt", "w") as txt_file:
            for link in self.link_to_crawl:
                txt_file.write(f"[{link['num_found']}]{link['text']} --> {link['href']} obtained from {link['source']}\n")

    def store_corpus_to_file(self, foldername):
        print(f"[MAINDRIVER {self.role}] Storing the corpus to files in dir:", foldername)
        count = 1
        dir_location = os.path.join(os.getcwd(), 'corpus', foldername)
        if not os.path.exists(dir_location):
            os.makedirs(dir_location, exist_ok=True)

        for data in self.corpus:
            filename = f"{count}.yaml"
            with open(f"{dir_location}/{filename}", "w") as txt_file:
                txt_file.write(convert_request_to_yaml(data))
            count += 1

    def load_corpus_from_file(self, foldername="default"):
        print(f"[MAINDRIVER {self.role}] Loading the corpus from files in dir:", foldername)
        dir_location = os.path.join(os.getcwd(), 'corpus', foldername)

        for filename in os.listdir(dir_location):
            request = convert_yaml_file_to_request(f"{dir_location}/{filename}")
            self.save_to_corpus(request, False)

    def store_request_to_file_as_attack_surface(self, request, foldername="default"):
        if "PROJECT_NAME" in config.data:
            foldername = config.data["PROJECT_NAME"]
        print(f"[MAINDRIVER {self.role}] Storing the request as the attack surface to a file in dir:", foldername)
        project_location = os.path.join(os.getcwd(), '../attack_surface', foldername)
        dir_location = os.path.join(project_location, self.role)
        if not os.path.exists(dir_location):
            os.makedirs(dir_location, exist_ok=True)

        filename = f"{self.corpus_length}.yaml"
        request.saved_filename = filename
        with open(f"{dir_location}/{filename}", "w") as txt_file:
            txt_file.write(convert_request_to_yaml(request))


    def save_captured_requests(self, start_time):
        filename = f"[REQ]{self.role}_{start_time.hour}{start_time.minute}{start_time.second}{start_time.microsecond}"
        print(f"[MAINDRIVER {self.role}] Storing the captured requests to: ../result/{filename}.txt")
        with open(f"../result/{filename}.txt", "w") as txt_file:
            i = 0
            for request in self.corpus:
                i += 1
                txt_file.write(f"{i}. {request}\n")

    async def web_error_handler(self,web_error):
        print(f"[MAINDRIVER {self.role}] Finding a web error: {web_error.error}")
        if web_error.page:
            print(f"[MAINDRIVER {self.role}] The web error is from {web_error.page}")

    async def crawl_new_page(self, page):
        opener = await page.opener()
        print(f"[MAINDRIVER {self.role}] OPENING A NEW TAB! CRAWLING THE NEW PAGE: {page.url} from {opener.url if opener else None}")

        url = page.url
        if url.startswith("http"):
            await page.close()
            print(f"[MAINDRIVER {self.role}] Save the new tab URL in the link to crawl later: {page.url}")
            self.save_link(page.url)
            return True

        elif url!="about:blank":
            await page.wait_for_load_state()
            await self.get_crawled_links(page)
            await self.find_and_fill_forms(page)
            await self.find_and_click_buttons(page)

        await page.close()

    async def drop_link(self, link):
        """
        We drop the link to free more space in memory
        :param link:
        :return:
        """
        pass

    def select_link(self):
        for i in self.idx_priority_links:
            if self.link_to_crawl[i]['is_visited']:
                print(f"[MAINDRIVER {self.role}] Removing a link index {i} from the priority queue because it is visited")
                self.idx_priority_links.remove(i)
            elif self.link_to_crawl[i]['num_click'] >= 5:
                print(f"[MAINDRIVER {self.role}] Removing a link index {i} from the priority queue because it was visited more than 5 times")
                self.idx_priority_links.remove(i)
            else:
                print(f"[MAINDRIVER {self.role}] Selecting a link from the priority queue: {i}")
                return self.link_to_crawl[i]

        start_idx = self.last_process_link_idx + 1
        if start_idx<len(self.link_to_crawl):
            for idx_link in range(start_idx,len(self.link_to_crawl)):
                link = self.link_to_crawl[idx_link]
                if link['is_visited'] or link['num_click'] >= 5:
                    link['locator'] = None
                    print(f"[MAINDRIVER {self.role}] Free up the locator field in the link: {link['text']} because it is visited")
                else:
                    self.last_process_link_idx = idx_link
                    return link
        print(f"[MAINDRIVER {self.role}] All links have been visited. Completing the Driver.")
        return None


    def calculate_coverage(self):
        for f in os.listdir(config.data['COV_PATHS']):
            filename = join(config.data['COV_PATHS'], f)
            if isfile(filename):
                print(f"[MAINDRIVER {self.role}] Calculating coverage from ", filename)
                try:
                    read_cov_from_file(filename)
                except Exception as e:
                    print(e)

                print(f"[MAINDRIVER {self.role}] Deleting the file {filename} after getting the coverage")
                try:
                    os.system(f"rm {filename}")
                except Exception as e:
                    print(e)

        foldername="default"
        if "PROJECT_NAME" in config.data:
            foldername = config.data["PROJECT_NAME"]
        dir_location = os.path.join(os.getcwd(), '../attack_surface', foldername)
        if not os.path.exists(dir_location):
            os.makedirs(dir_location, exist_ok=True)

        filename = f"coverage-{self.start_time.timestamp()}.csv"
        with open(f"{dir_location}/{filename}", "a") as csv_file:
            writer = csv.writer(csv_file, delimiter=',')
            writer.writerow([datetime.now().timestamp(), len(config.line_coverage)])

        delete_files(config.data['MYSQL_PATHS'])

    async def handle_popup(self, popup):
        await popup.wait_for_load_state()
        print(f"[MAINDRIVER {self.role}] Getting a popup: {await popup.title()}")
        buttons = await popup.get_by_role("button").all()

        for button in buttons:
            button_name = await button.inner_text(timeout=2000)
            print(f"[MAINDRIVER {self.role}] Click a button: {button_name} to close the popup")
            try:
                if (await button.is_visible() and await button.is_enabled()):
                    await button.click(force=True)
                    self.trigger = button_name
            except Exception as e:
                data_title = f"../data/button-{randomword(10)}.jpeg"
                await self.page.screenshot(path=data_title)
                print(f"[MAINDRIVER {self.role}] {str(e)[-100:]}")
                print(f"[MAINDRIVER {self.role}] Button is not in the viewport! Clicking action is failed")
                print(f"[MAINDRIVER {self.role}] Saving the screenshot in {data_title}")

    async def handle_dialog(self, dialog):
        print(f"[MAINDRIVER {self.role}] Getting Dialog: {dialog.message}")
        error = False
        try:
            await dialog.accept()
        except Exception as e:
            error = True
            print(f"[MAINDRIVER {self.role}] Error in Accepting Dialog: {str(e)[-100:]}")

        if error:
            try:
                await dialog.dismiss()
            except Exception as e:
                print(f"[MAINDRIVER {self.role}] Error in Dismissing Dialog: {str(e)[-100:]}")

    async def crawl_page(self, page_url=None, nested_number=0):
        if nested_number>5:
            return False

        if page_url:
            await self.page.goto(page_url)
        else:
            page_url = self.page.url

        try:
            await self.page.wait_for_load_state('domcontentloaded')
            await self.get_crawled_links()
            await self.find_and_fill_forms()
            await self.find_and_click_buttons()
        except Exception as e:
            print(f"[MAINDRIVER {self.role}] ERROR IN CRAWLING: {str(e)[-100:]}")

    async def crawl(self, homepage=None, is_saving_request=True):
        print(f"[MAINDRIVER {self.role}] -------MAIN DRIVER IS STARTING TO CRAWL-------")
        page = self.page
        if is_saving_request:
            await self.context.route("**/*", self.new_abort_req_and_save_to_corpus)

        # self.context.on("page", self.crawl_new_page)
        self.context.on("weberror", self.web_error_handler)
        self.page.on("dialog", self.handle_dialog)
        self.page.on("popup", self.crawl_new_page)
        self.context.on("filechooser", lambda file_chooser: file_chooser.set_files("free.jpg"))

        try:
            if homepage==None:
                homepage = config.data["HOMEPAGE_URL"]
            print(f"[MAINDRIVER {self.role}] Opening {homepage}")
            await self.page.goto(homepage)
            await self.page.wait_for_load_state('domcontentloaded')

            self.is_crawling_complete = False
            await self.get_crawled_links()
            await self.find_and_fill_forms()
            await self.find_and_click_buttons()
            self.is_crawling_complete = True
        except Exception as e:
            print(f"[MAINDRIVER {self.role}] ERROR IN THE BEGINNING. EXCEPTION MSG: {str(e)[-100:]}")

        exec_num = 0
        link = self.select_link()
        current_time = datetime.now()
        while link and current_time < config.finish_time:
            is_not_in_viewport = False
            self.is_crawling_complete = True
            error_to_open = False
            exec_num +=1
            print(f"[MAINDRIVER {self.role}] Execution number: {exec_num}/{len(self.link_to_crawl)} with link index: {link['idx']}")
            print(f"[MAINDRIVER {self.role}] Going to click [{link['text']}] with href: {link['href']} obtained from page: {link['source']}")
            link['num_click'] +=1
            try:
                if ("locator" in link and await link['locator'].is_visible() and await link['locator'].is_enabled() and link['source']==self.page.url):

                    init_url = self.page.url

                    await link['locator'].click(force=True)
                    self.trigger = link['text']
                    await self.page.wait_for_load_state('domcontentloaded')

                    if init_url == self.page.url:
                        is_not_in_viewport = True
                        print(f"[MAINDRIVER {self.role}] URL is not changed. Trying to go directly to the url")
                    else:
                        self.is_crawling_complete = False
                        await self.get_crawled_links()
                        await self.find_and_fill_forms()
                        await self.find_and_click_buttons()
                else:
                    print(f"[MAINDRIVER {self.role}] Link is not visible or enabled! Trying to go directly to the url")
                    is_not_in_viewport = True
            except Exception as e:
                print(f"[MAINDRIVER {self.role}] Link is not in the viewport! Trying to go directly to the url")
                is_not_in_viewport = True

            if is_not_in_viewport:
                try:
                    is_not_in_viewport = False
                    full_link = link['href']
                    if is_same_domain(full_link):
                        print(f"[MAINDRIVER {self.role}] Go to",full_link)
                        await self.page.goto(full_link)
                        await self.page.wait_for_load_state('domcontentloaded')

                        self.is_crawling_complete = False
                        await self.get_crawled_links()
                        await self.find_and_fill_forms()
                        await self.find_and_click_buttons()
                    else:
                        print(f"[MAINDRIVER {self.role}] The link",full_link,"is not same domain with the main page")
                except Exception as e:
                    error_to_open = True
                    print(f"[MAINDRIVER {self.role}] EXCEPTION MSG: {e}")


            if not error_to_open:
                link['is_visited'] = True
                link['locator'] = None
                print(f"[MAINDRIVER {self.role}] Drop the locator field in the link: {link['text']} because it is visited")
            else:
                print(f"[MAINDRIVER {self.role}] There is error when opening the link: {link['text']}. We will try it later")


            link = self.select_link()
            if link and 'href' in link and "vulnerabilities/csrf" in link['href']:
                link['is_visited'] = True
                link['locator'] = None
                print(f"[MAINDRIVER {self.role}] Skip the link: {link['text']} because it is prohibited")
                link = self.select_link()

            current_time = datetime.now()

        try:
            self.save_crawled_link_to_txt(datetime.now())
            self.save_captured_requests(datetime.now())

            await self.context.close()
            await self.browser.close()
        except Exception as e:
            print(f"[MAINDRIVER {self.role}] EXCEPTION MSG: {e}")
