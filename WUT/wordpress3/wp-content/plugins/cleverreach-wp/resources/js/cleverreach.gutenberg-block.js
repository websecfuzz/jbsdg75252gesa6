(function (blocks, i18n, editor, element, components) {

	var el = element.createElement,
		InspectorControls = editor.InspectorControls, // sidebar controls
		ServerSideRender = components.ServerSideRender, // sidebar controls
		PanelBody = components.PanelBody; // sidebar panel

	/**
	 * Creates dropdown options
	 *
	 * @param {array} items array of options
	 * @param {string} selectedFormId
	 */
	function createFormList(items, selectedFormId) {
		items.push(el('option', {
			value: 0,
			selected: (!showFormContent(selectedFormId)),
			disabled: true
		}, cleverReachFormsBlock.translations.select_and_display_forms));
		_.each(cleverReachFormsBlock.forms, function (form) {
			items.push(el('option',
				{
					value: form.form_id,
					selected: (parseInt(form.form_id) === parseInt(selectedFormId)),
					title: form.name
				},
				form.name.substr(0, 100)
			))
		});
	}

	/**
	 * Return selected form url
	 *
	 * @param formId
	 *
	 * @returns url of selected form
	 */
	function getSelectedFormUrl(formId) {
		for (let i = 0; i < cleverReachFormsBlock.forms.length; i++) {
			if (cleverReachFormsBlock.forms[i].form_id === formId) {
				return cleverReachFormsBlock.forms[i].url;
			}
		}
	}

	/**
	 * Renders CleverReach select form page
	 *
	 * @param {array} itemsToAdd
	 * @param {array} children
	 */
	function showSelectFormsPage(itemsToAdd, children) {
		let contentItems = [];
		for (let i = 0; i < itemsToAdd.length; i++) {
			contentItems.push(itemsToAdd[i]);
		}

		let content = el('div', {className: 'cr-gutenberg-form-config-container'}, contentItems);
		children.push(content);
	}

	/**
	 * Creates element that renders form html from backend
	 *
	 * @param props
	 * @param formID
	 * @returns {*}
	 */
	function createServerSideRenderForm(props, formID) {
		return el(ServerSideRender, {
			key: 'cr-gutenberg-forms-render',
			className: 'cr-form-' + formID,
			block: "cleverreach/subscription-form",
			attributes: props.attributes
		});
	}

	/**
	 * Checks whether form content should be shown
	 *
	 * @param {string} formId
	 * @returns {boolean|*}
	 */
	function showFormContent(formId) {
		if (!formId) {
			return false;
		}

		let existingFormIds = cleverReachFormsBlock.forms.map(form => form.form_id);

		return existingFormIds.includes(formId);
	}

	/**
	 * Adds sidebar settings items
	 *
	 * @param {array} items elements that should be added to sidebar
	 * @param {array} children global return value
	 */
	function addSidebarSettings(items, children) {
		// Set up the form dropdown and link in the side bar 'block' settings
		let inspectorControls = el(InspectorControls, {},
			el(PanelBody, {title: cleverReachFormsBlock.translations.form_settings},
				el('span', null, cleverReachFormsBlock.translations.form),
				items
			)
		);
		children.push(inspectorControls);
	}

	/**
	 * Periodically checks whether the form code from CleverReach has been loaded into page.
	 *
	 * @param formID
	 */
	function checkIsFormLoaded(formID) {
		let timer = setInterval(function () {
			if (reinitializeScripts(formID)) {
				clearInterval(timer);
			}
		}, 500);
	}

	/**
	 * Re-initializes form scripts, if the form has been loaded in page.
	 *
	 * @param formID
	 * @returns {boolean}
	 */
	function reinitializeScripts(formID) {
		let form = document.querySelector('.cr-form-' + formID);

		if (typeof form === 'undefined' || form.querySelector('.cr_form') === null) {
			return false;
		}

		Array.from(form.querySelectorAll("script")).forEach(oldScript => {
			const newScript = document.createElement("script");
			Array.from(oldScript.attributes)
				.forEach(attr => newScript.setAttribute(attr.name, attr.value));
			newScript.appendChild(document.createTextNode(oldScript.innerHTML));
			oldScript.parentNode.replaceChild(newScript, oldScript);
		});

		return true;
	}

	let crIcon = wp.element.createElement('svg',
		{
			width: 30,
			height: 30,
			xmlns: 'http://www.w3.org/2000/svg',
			viewBox: '0 0 32 32',
			color: '#ec6702',
			fill: '#ec6702'
		},
		wp.element.createElement( 'path',
			{
				d: 'M29.0358 7.0111C31.0121 8.64698 31.9997 10.9797 32 13.8862C32 17.8045 29.9888 20.3139 26.4509 21.6146C26.4484 21.6156 26.4465 21.6178 26.4465 21.621C26.4471 22.3252 26.6823 22.9983 27.0147 23.9291C27.1147 24.2086 27.2724 24.536 27.4322 24.871L27.4802 24.9717C27.4908 24.9941 27.5014 25.0165 27.512 25.0389L27.5437 25.1062C27.8751 25.8124 28.1586 26.5105 27.8795 26.8267C27.4286 27.3365 26.0188 27.1704 24.6171 26.5825C23.2154 25.9935 22.4177 25.2446 21.7715 24.4844C21.3407 23.978 21.0406 23.4688 20.7628 23.022C20.4995 22.5989 20.4343 22.2954 19.9655 22.3265C19.0016 22.4033 18.037 22.484 17.0728 22.5656C16.8801 22.5819 16.7146 22.4299 16.7146 22.2356V18.1828C16.7146 18.0106 16.8462 17.8669 17.0179 17.8525C18.4547 17.7309 19.8916 17.6112 21.3282 17.5027C24.7408 17.2454 26.4461 15.8793 26.4465 13.217C26.4461 10.6634 24.7437 9.42699 21.3381 9.64048L21.1575 9.65264C19.7961 9.75635 18.4343 9.86933 17.0728 9.98456C16.8801 10.0006 16.7146 9.84853 16.7146 9.65456V5.60151C16.7146 5.42931 16.8462 5.28592 17.0179 5.2712C18.4941 5.14637 19.9699 5.02378 21.4458 4.91272C24.4896 4.68195 27.0192 5.37618 29.0358 7.0111ZM14.2913 5.88557V9.94897C14.2913 10.1219 14.1584 10.2662 13.986 10.28L9.52312 10.6421C6.37357 11.0036 4.79927 12.3534 4.79895 14.8165C4.79927 17.3669 6.37357 18.6207 9.52312 18.5027L13.9337 18.163C14.1266 18.1479 14.2913 18.3003 14.2913 18.4937V22.5571C14.2913 22.73 14.1587 22.874 13.9864 22.8885C12.0783 23.0472 10.1705 23.1993 8.26208 23.3231C8.19404 23.3257 8.126 23.3289 8.05827 23.3318C5.73005 23.4087 3.83961 22.6947 2.34395 21.2212C0.772865 19.6728 0.000320957 17.5783 0 14.9666C0 14.2526 0.0664381 13.5758 0.19771 12.9346L0.206696 12.8916C0.542739 11.2865 1.29089 9.90439 2.44056 8.70217C3.98308 7.11184 5.94252 6.21692 8.27781 5.99142L13.9334 5.55455C14.1266 5.53979 14.2913 5.69247 14.2913 5.88557Z'
			}
		)
	);

	// register our block
	blocks.registerBlockType('cleverreach/subscription-form', {
		title: cleverReachFormsBlock.translations.subscription_form,
		icon: crIcon,
		category: 'cleverreach',
		attributes: {
			formID: {
				type: 'string'
			},
			renderForm: {
				type: 'boolean'
			}

		},

		supports: {
			html: false
		},

		edit: function (props) {
			let formID = props.attributes.formID;
			let formItems = [];
			let children = [];

			createFormList(formItems, formID);

			/**
			 * Set form id when CleverReach form is selected
			 *
			 * @param event
			 */
			function formSelected(event) {
				//set the attributes from the selected for item
				let selectElement = event.target;
				event.preventDefault();
				props.setAttributes({
					formID: selectElement.options[selectElement.selectedIndex].value,
				});
			}

			// text element
			let textItem = el('div', {className: 'cr-gutenberg-form-config-item cr-gutenberg-form-config-item-text'},
				el('div', {className: 'cr-gutenberg-form-config-text-message'},
					cleverReachFormsBlock.translations.insert_form
				)
			);

			// dropdown element
			let selectItem = el('div', {className: 'cr-gutenberg-form-config-item'},
				el('select', {onChange: formSelected}, formItems)
			);

			let formLink = showFormContent(formID) ?
				el('a', {href: getSelectedFormUrl(formID), target: '_blank'},
					el('span', {}, cleverReachFormsBlock.translations.edit_in_cleverreach),
					el('img', {
						className: 'cr-learn-button',
						src: 'data:image/svg+xml;utf8,%3Csvg%20xmlns%3D%22http%3A%2F%2Fwww.w3.org%2F2000%2Fsvg%22%20viewBox%3D%220%200%2020%2020%22%3E%3Cpath%20fill%3D%22%23212B36%22%20d%3D%22M13%2012a1%201%200%200%201%201%201v1a1%201%200%200%201-1%201H6c-.575%200-1-.484-1-1V7a1%201%200%200%201%201-1h1a1%201%200%200%201%200%202v5h5a1%201%200%200%201%201-1zm-2-7h4v4a1%201%200%201%201-2%200v-.586l-2.293%202.293a.999.999%200%201%201-1.414-1.414L11.586%207H11a1%201%200%200%201%200-2z%22%2F%3E%3C%2Fsvg%3E%0A'
					})
				)
				: null;

			addSidebarSettings([selectItem, formLink], children);

			if (showFormContent(formID)) {
				if (!props.attributes.renderForm) {
					setTimeout(function () {
						props.setAttributes({
							renderForm:true,
							formID: formID,
						});
					}, 0);

					showSelectFormsPage([textItem, selectItem], children);

					return [children];
				}

				children.push(createServerSideRenderForm(props, formID));

				checkIsFormLoaded(formID);
			} else {
				showSelectFormsPage([textItem, selectItem], children);
			}

			return [children];
		},

		save: function () {
			return null;
		}
	});
})(
	window.wp.blocks,
	window.wp.i18n,
	window.wp.editor,
	window.wp.element,
	window.wp.components
);
