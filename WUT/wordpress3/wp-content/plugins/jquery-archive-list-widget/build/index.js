/******/ (() => { // webpackBootstrap
/******/ 	"use strict";
/******/ 	var __webpack_modules__ = ({

/***/ "./src/components/admin/CategoryPicker.js":
/*!************************************************!*\
  !*** ./src/components/admin/CategoryPicker.js ***!
  \************************************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "default": () => (__WEBPACK_DEFAULT_EXPORT__)
/* harmony export */ });
/* harmony import */ var react__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! react */ "react");
/* harmony import */ var react__WEBPACK_IMPORTED_MODULE_0___default = /*#__PURE__*/__webpack_require__.n(react__WEBPACK_IMPORTED_MODULE_0__);
/* harmony import */ var _wordpress_i18n__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! @wordpress/i18n */ "@wordpress/i18n");
/* harmony import */ var _wordpress_i18n__WEBPACK_IMPORTED_MODULE_1___default = /*#__PURE__*/__webpack_require__.n(_wordpress_i18n__WEBPACK_IMPORTED_MODULE_1__);
/* harmony import */ var _wordpress_components__WEBPACK_IMPORTED_MODULE_2__ = __webpack_require__(/*! @wordpress/components */ "@wordpress/components");
/* harmony import */ var _wordpress_components__WEBPACK_IMPORTED_MODULE_2___default = /*#__PURE__*/__webpack_require__.n(_wordpress_components__WEBPACK_IMPORTED_MODULE_2__);
/* harmony import */ var _wordpress_data__WEBPACK_IMPORTED_MODULE_3__ = __webpack_require__(/*! @wordpress/data */ "@wordpress/data");
/* harmony import */ var _wordpress_data__WEBPACK_IMPORTED_MODULE_3___default = /*#__PURE__*/__webpack_require__.n(_wordpress_data__WEBPACK_IMPORTED_MODULE_3__);

/**
 * WordPress dependencies
 */



const CategoryPicker = ({
  selectedCats,
  onSelected
}) => {
  const categories = (0,_wordpress_data__WEBPACK_IMPORTED_MODULE_3__.useSelect)(select => select('core').getEntityRecords('taxonomy', 'category', {
    per_page: 100
  }));
  const isLoading = (0,_wordpress_data__WEBPACK_IMPORTED_MODULE_3__.useSelect)(select => {
    return select('core/data').isResolving('core', 'getEntityRecords', ['taxonomy', 'category', {
      per_page: 100
    }]);
  });
  if (isLoading) {
    return (0,react__WEBPACK_IMPORTED_MODULE_0__.createElement)("h3", null, (0,_wordpress_i18n__WEBPACK_IMPORTED_MODULE_1__.__)('Loading categories…', 'jalw_i18n'));
  }
  if (categories === null) {
    return (0,react__WEBPACK_IMPORTED_MODULE_0__.createElement)("p", null, "No categories found");
  }
  return (0,react__WEBPACK_IMPORTED_MODULE_0__.createElement)(_wordpress_components__WEBPACK_IMPORTED_MODULE_2__.SelectControl, {
    hideLabelFromVision: true,
    multiple: true,
    options: categories.map(({
      id,
      name
    }) => ({
      label: name,
      value: id
    })),
    onChange: selected => {
      onSelected(selected);
    },
    style: {
      minWidth: '250px',
      height: '100px'
    },
    value: selectedCats
  });
};
/* harmony default export */ const __WEBPACK_DEFAULT_EXPORT__ = (CategoryPicker);

/***/ }),

/***/ "./src/components/frontend/JsArchiveList.js":
/*!**************************************************!*\
  !*** ./src/components/frontend/JsArchiveList.js ***!
  \**************************************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "default": () => (__WEBPACK_DEFAULT_EXPORT__)
/* harmony export */ });
/* harmony import */ var react__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! react */ "react");
/* harmony import */ var react__WEBPACK_IMPORTED_MODULE_0___default = /*#__PURE__*/__webpack_require__.n(react__WEBPACK_IMPORTED_MODULE_0__);
/* harmony import */ var _wordpress_element__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! @wordpress/element */ "@wordpress/element");
/* harmony import */ var _wordpress_element__WEBPACK_IMPORTED_MODULE_1___default = /*#__PURE__*/__webpack_require__.n(_wordpress_element__WEBPACK_IMPORTED_MODULE_1__);
/* harmony import */ var _wordpress_i18n__WEBPACK_IMPORTED_MODULE_2__ = __webpack_require__(/*! @wordpress/i18n */ "@wordpress/i18n");
/* harmony import */ var _wordpress_i18n__WEBPACK_IMPORTED_MODULE_2___default = /*#__PURE__*/__webpack_require__.n(_wordpress_i18n__WEBPACK_IMPORTED_MODULE_2__);
/* harmony import */ var _components_displayers_DisplayYear__WEBPACK_IMPORTED_MODULE_3__ = __webpack_require__(/*! ./components/displayers/DisplayYear */ "./src/components/frontend/components/displayers/DisplayYear.js");
/* harmony import */ var _context_ConfigContext__WEBPACK_IMPORTED_MODULE_4__ = __webpack_require__(/*! ./context/ConfigContext */ "./src/components/frontend/context/ConfigContext.js");
/* harmony import */ var _components_ShowOlderYears__WEBPACK_IMPORTED_MODULE_5__ = __webpack_require__(/*! ./components/ShowOlderYears */ "./src/components/frontend/components/ShowOlderYears.js");
/* harmony import */ var _hooks_useApi__WEBPACK_IMPORTED_MODULE_6__ = __webpack_require__(/*! ./hooks/useApi */ "./src/components/frontend/hooks/useApi.js");
/* harmony import */ var _components_Loading__WEBPACK_IMPORTED_MODULE_7__ = __webpack_require__(/*! ./components/Loading */ "./src/components/frontend/components/Loading.js");

/**
 * WordPress dependencies
 */



/**
 * Internal dependencies
 */





const JsArchiveList = () => {
  const {
    config
  } = (0,_wordpress_element__WEBPACK_IMPORTED_MODULE_1__.useContext)(_context_ConfigContext__WEBPACK_IMPORTED_MODULE_4__.ConfigContext);
  const [loaded, setLoaded] = (0,_wordpress_element__WEBPACK_IMPORTED_MODULE_1__.useState)(false);
  const {
    loading,
    data: apiData,
    error,
    apiClient: loadYears
  } = (0,_hooks_useApi__WEBPACK_IMPORTED_MODULE_6__["default"])('/jalw/v1/archive');
  const yearsToShow = (0,_wordpress_element__WEBPACK_IMPORTED_MODULE_1__.useMemo)(() => {
    const loadedYears = apiData ? apiData.years : [];
    if (config.hide_from_year && !isNaN(config.hide_from_year)) {
      return {
        current: loadedYears.filter(yearObj => yearObj.year >= config.hide_from_year),
        olders: loadedYears.filter(yearObj => yearObj.year < config.hide_from_year)
      };
    }
    return {
      current: loadedYears,
      olders: []
    };
  }, [apiData, config]);

  /* eslint-disable react-hooks/exhaustive-deps */
  (0,_wordpress_element__WEBPACK_IMPORTED_MODULE_1__.useEffect)(() => {
    loadYears(config);
  }, []);
  (0,_wordpress_element__WEBPACK_IMPORTED_MODULE_1__.useEffect)(() => {
    if (!loaded && (error || loaded)) {
      setLoaded(true);
    }
  }, [loaded, error]);
  return (0,react__WEBPACK_IMPORTED_MODULE_0__.createElement)("div", {
    className: "js-archive-list dynamic"
  }, (0,react__WEBPACK_IMPORTED_MODULE_0__.createElement)("h2", null, config.title), loading ? (0,react__WEBPACK_IMPORTED_MODULE_0__.createElement)("div", null, (0,react__WEBPACK_IMPORTED_MODULE_0__.createElement)(_components_Loading__WEBPACK_IMPORTED_MODULE_7__["default"], {
    loading: loading
  }), (0,_wordpress_i18n__WEBPACK_IMPORTED_MODULE_2__.__)('Loading…', 'jalw')) : '', apiData && apiData.years ? (0,react__WEBPACK_IMPORTED_MODULE_0__.createElement)("ul", {
    className: "jaw_widget"
  }, yearsToShow.current.length === 0 ? (0,react__WEBPACK_IMPORTED_MODULE_0__.createElement)("li", null, (0,_wordpress_i18n__WEBPACK_IMPORTED_MODULE_2__.__)('There are no post to show.', 'jalw')) : yearsToShow.current.map(yearObj => (0,react__WEBPACK_IMPORTED_MODULE_0__.createElement)(_components_displayers_DisplayYear__WEBPACK_IMPORTED_MODULE_3__["default"], {
    key: yearObj.year,
    yearObj: yearObj
  })), yearsToShow.olders.length > 0 ? (0,react__WEBPACK_IMPORTED_MODULE_0__.createElement)(_components_ShowOlderYears__WEBPACK_IMPORTED_MODULE_5__["default"], {
    years: yearsToShow.olders
  }) : '') : '', (loaded || error) && !apiData ? (0,_wordpress_i18n__WEBPACK_IMPORTED_MODULE_2__.__)('Cannot load posts.', 'jalw') : '');
};
/* harmony default export */ const __WEBPACK_DEFAULT_EXPORT__ = (JsArchiveList);

/***/ }),

/***/ "./src/components/frontend/components/BulletWithSymbol.js":
/*!****************************************************************!*\
  !*** ./src/components/frontend/components/BulletWithSymbol.js ***!
  \****************************************************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "default": () => (__WEBPACK_DEFAULT_EXPORT__)
/* harmony export */ });
/* harmony import */ var react__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! react */ "react");
/* harmony import */ var react__WEBPACK_IMPORTED_MODULE_0___default = /*#__PURE__*/__webpack_require__.n(react__WEBPACK_IMPORTED_MODULE_0__);
/* harmony import */ var _wordpress_element__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! @wordpress/element */ "@wordpress/element");
/* harmony import */ var _wordpress_element__WEBPACK_IMPORTED_MODULE_1___default = /*#__PURE__*/__webpack_require__.n(_wordpress_element__WEBPACK_IMPORTED_MODULE_1__);
/* harmony import */ var _context_ConfigContext__WEBPACK_IMPORTED_MODULE_2__ = __webpack_require__(/*! ../context/ConfigContext */ "./src/components/frontend/context/ConfigContext.js");
/* harmony import */ var _hooks_useFrontend__WEBPACK_IMPORTED_MODULE_3__ = __webpack_require__(/*! ../hooks/useFrontend */ "./src/components/frontend/hooks/useFrontend.js");

/**
 * WordPress dependencies
 */


/**
 * Internal dependencies
 */


const BulletWithSymbol = ({
  expanded,
  expandSubLevel,
  title,
  permalink,
  onToggle
}) => {
  const {
    config
  } = (0,_wordpress_element__WEBPACK_IMPORTED_MODULE_1__.useContext)(_context_ConfigContext__WEBPACK_IMPORTED_MODULE_2__.ConfigContext);
  const {
    expandSymbol,
    collapseSymbol
  } = (0,_hooks_useFrontend__WEBPACK_IMPORTED_MODULE_3__.useSymbol)(config.symbol);
  const expandedClass = expanded && expandSubLevel ? 'expanded' : '';
  const symbol = expanded ? collapseSymbol : expandSymbol;

  // Do not show the component if it's disabled in the options.
  if (config.symbol.toString() === '0') {
    return '';
  }
  return (0,react__WEBPACK_IMPORTED_MODULE_0__.createElement)("a", {
    href: permalink,
    title: title,
    className: `${expandedClass} jaw_symbol`,
    onClick: onToggle
  }, symbol);
};
/* harmony default export */ const __WEBPACK_DEFAULT_EXPORT__ = (BulletWithSymbol);

/***/ }),

/***/ "./src/components/frontend/components/ListWithAnimation.js":
/*!*****************************************************************!*\
  !*** ./src/components/frontend/components/ListWithAnimation.js ***!
  \*****************************************************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "default": () => (__WEBPACK_DEFAULT_EXPORT__)
/* harmony export */ });
/* harmony import */ var react__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! react */ "react");
/* harmony import */ var react__WEBPACK_IMPORTED_MODULE_0___default = /*#__PURE__*/__webpack_require__.n(react__WEBPACK_IMPORTED_MODULE_0__);
/* harmony import */ var _wordpress_element__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! @wordpress/element */ "@wordpress/element");
/* harmony import */ var _wordpress_element__WEBPACK_IMPORTED_MODULE_1___default = /*#__PURE__*/__webpack_require__.n(_wordpress_element__WEBPACK_IMPORTED_MODULE_1__);
/* harmony import */ var _BulletWithSymbol__WEBPACK_IMPORTED_MODULE_2__ = __webpack_require__(/*! ./BulletWithSymbol */ "./src/components/frontend/components/BulletWithSymbol.js");
/* harmony import */ var _Loading__WEBPACK_IMPORTED_MODULE_3__ = __webpack_require__(/*! ./Loading */ "./src/components/frontend/components/Loading.js");
/* harmony import */ var _context_ConfigContext__WEBPACK_IMPORTED_MODULE_4__ = __webpack_require__(/*! ../context/ConfigContext */ "./src/components/frontend/context/ConfigContext.js");

/**
 * WordPress dependencies
 */


/**
 * Internal dependencies
 */



const ListWithAnimation = ({
  children,
  items,
  expand,
  initialExpand,
  link,
  loading,
  rootLink,
  showToggleSymbol,
  subListCustomClass
}) => {
  const {
    animationFunction
  } = (0,_wordpress_element__WEBPACK_IMPORTED_MODULE_1__.useContext)(_context_ConfigContext__WEBPACK_IMPORTED_MODULE_4__.ConfigContext);
  const listElement = (0,_wordpress_element__WEBPACK_IMPORTED_MODULE_1__.useRef)(null);
  const [isExpanded, setIsExpanded] = (0,_wordpress_element__WEBPACK_IMPORTED_MODULE_1__.useState)(expand);
  const animateList = (0,_wordpress_element__WEBPACK_IMPORTED_MODULE_1__.useCallback)(() => {
    const archiveList = [...listElement.current.children].filter(ch => ch.nodeName.toLowerCase() === 'ul');
    if (archiveList.length > 0) animationFunction(archiveList[0]);
  }, [listElement, animationFunction]);
  const liClass = expand ? 'expanded' : '';
  const loopItems = Array.isArray(items) || !items ? items : [];
  const hasItems = loopItems && loopItems.length && loopItems.length > 0;
  (0,_wordpress_element__WEBPACK_IMPORTED_MODULE_1__.useEffect)(() => {
    if (listElement && !!initialExpand) {
      if (showToggleSymbol && listElement.current.children[0]) {
        listElement.current.children[0].click();
      }
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);
  (0,_wordpress_element__WEBPACK_IMPORTED_MODULE_1__.useEffect)(() => {
    if (expand !== isExpanded) {
      setIsExpanded(expand);
      animateList();
    }
  }, [expand, animateList, isExpanded]);
  return (0,react__WEBPACK_IMPORTED_MODULE_0__.createElement)("li", {
    ref: listElement,
    className: liClass
  }, showToggleSymbol || items.length > 0 ? (0,react__WEBPACK_IMPORTED_MODULE_0__.createElement)(_BulletWithSymbol__WEBPACK_IMPORTED_MODULE_2__["default"], {
    expanded: isExpanded,
    expandSubLevel: rootLink.expand,
    title: rootLink.title,
    permalink: link.href,
    onToggle: rootLink.onClick
  }) : '', (0,react__WEBPACK_IMPORTED_MODULE_0__.createElement)("a", {
    href: link.href,
    title: link.title,
    onClick: link.onClick
  }, link.content, (0,react__WEBPACK_IMPORTED_MODULE_0__.createElement)(_Loading__WEBPACK_IMPORTED_MODULE_3__["default"], {
    loading: loading
  })), hasItems ? (0,react__WEBPACK_IMPORTED_MODULE_0__.createElement)("ul", {
    className: subListCustomClass + ' jal-hide'
  }, loopItems.map((item, index) => children(item, index))) : '');
};
/* harmony default export */ const __WEBPACK_DEFAULT_EXPORT__ = (ListWithAnimation);

/***/ }),

/***/ "./src/components/frontend/components/Loading.js":
/*!*******************************************************!*\
  !*** ./src/components/frontend/components/Loading.js ***!
  \*******************************************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "default": () => (__WEBPACK_DEFAULT_EXPORT__)
/* harmony export */ });
/* harmony import */ var react__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! react */ "react");
/* harmony import */ var react__WEBPACK_IMPORTED_MODULE_0___default = /*#__PURE__*/__webpack_require__.n(react__WEBPACK_IMPORTED_MODULE_0__);

const Loading = ({
  loading
}) => {
  if (loading) {
    return (0,react__WEBPACK_IMPORTED_MODULE_0__.createElement)("div", {
      className: "loading",
      role: "progressbar"
    }, (0,react__WEBPACK_IMPORTED_MODULE_0__.createElement)("svg", {
      xmlns: "http://www.w3.org/2000/svg",
      x: "0",
      y: "0",
      version: "1.1",
      viewBox: "0 0 100 100",
      xmlSpace: "preserve"
    }, (0,react__WEBPACK_IMPORTED_MODULE_0__.createElement)("path", {
      fill: "#000",
      d: "M73 50c0-12.7-10.3-23-23-23S27 37.3 27 50m3.9 0c0-10.5 8.5-19.1 19.1-19.1S69.1 39.5 69.1 50"
    }, (0,react__WEBPACK_IMPORTED_MODULE_0__.createElement)("animateTransform", {
      attributeName: "transform",
      attributeType: "XML",
      dur: "1s",
      from: "0 50 50",
      repeatCount: "indefinite",
      to: "360 50 50",
      type: "rotate"
    }))));
  }
  return '';
};
/* harmony default export */ const __WEBPACK_DEFAULT_EXPORT__ = (Loading);

/***/ }),

/***/ "./src/components/frontend/components/ShowOlderYears.js":
/*!**************************************************************!*\
  !*** ./src/components/frontend/components/ShowOlderYears.js ***!
  \**************************************************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "default": () => (__WEBPACK_DEFAULT_EXPORT__)
/* harmony export */ });
/* harmony import */ var react__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! react */ "react");
/* harmony import */ var react__WEBPACK_IMPORTED_MODULE_0___default = /*#__PURE__*/__webpack_require__.n(react__WEBPACK_IMPORTED_MODULE_0__);
/* harmony import */ var _wordpress_element__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! @wordpress/element */ "@wordpress/element");
/* harmony import */ var _wordpress_element__WEBPACK_IMPORTED_MODULE_1___default = /*#__PURE__*/__webpack_require__.n(_wordpress_element__WEBPACK_IMPORTED_MODULE_1__);
/* harmony import */ var _displayers_DisplayYear__WEBPACK_IMPORTED_MODULE_2__ = __webpack_require__(/*! ./displayers/DisplayYear */ "./src/components/frontend/components/displayers/DisplayYear.js");

/**
 * WordPress dependencies
 */


/**
 * Internal dependencies
 */

const ShowOlderYears = ({
  years
}) => {
  const [showYears, setShowYears] = (0,_wordpress_element__WEBPACK_IMPORTED_MODULE_1__.useState)(false);
  const handleShowYears = evt => {
    evt.preventDefault();
    setShowYears(!showYears);
  };
  return (0,react__WEBPACK_IMPORTED_MODULE_0__.createElement)(react__WEBPACK_IMPORTED_MODULE_0__.Fragment, null, showYears ? years.map(yearObj => (0,react__WEBPACK_IMPORTED_MODULE_0__.createElement)(_displayers_DisplayYear__WEBPACK_IMPORTED_MODULE_2__["default"], {
    yearObj: yearObj,
    key: yearObj.year
  })) : (0,react__WEBPACK_IMPORTED_MODULE_0__.createElement)("li", null, (0,react__WEBPACK_IMPORTED_MODULE_0__.createElement)("a", {
    href: "#show",
    onClick: handleShowYears
  }, "Show Older Years")));
};
/* harmony default export */ const __WEBPACK_DEFAULT_EXPORT__ = (ShowOlderYears);

/***/ }),

/***/ "./src/components/frontend/components/displayers/DisplayDay.js":
/*!*********************************************************************!*\
  !*** ./src/components/frontend/components/displayers/DisplayDay.js ***!
  \*********************************************************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "default": () => (__WEBPACK_DEFAULT_EXPORT__)
/* harmony export */ });
/* harmony import */ var react__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! react */ "react");
/* harmony import */ var react__WEBPACK_IMPORTED_MODULE_0___default = /*#__PURE__*/__webpack_require__.n(react__WEBPACK_IMPORTED_MODULE_0__);
/* harmony import */ var _wordpress_element__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! @wordpress/element */ "@wordpress/element");
/* harmony import */ var _wordpress_element__WEBPACK_IMPORTED_MODULE_1___default = /*#__PURE__*/__webpack_require__.n(_wordpress_element__WEBPACK_IMPORTED_MODULE_1__);
/* harmony import */ var _DisplayPost__WEBPACK_IMPORTED_MODULE_2__ = __webpack_require__(/*! ./DisplayPost */ "./src/components/frontend/components/displayers/DisplayPost.js");
/* harmony import */ var _ListWithAnimation__WEBPACK_IMPORTED_MODULE_3__ = __webpack_require__(/*! ../ListWithAnimation */ "./src/components/frontend/components/ListWithAnimation.js");

/**
 * WordPress dependencies
 */


/**
 * Internal dependencies
 */


const DisplayDay = ({
  dayObj
}) => {
  const [expand, setExpand] = (0,_wordpress_element__WEBPACK_IMPORTED_MODULE_1__.useState)(false);
  const loadPosts = async event => {
    event.preventDefault();
    setExpand(!expand);
  };
  return (0,react__WEBPACK_IMPORTED_MODULE_0__.createElement)(_ListWithAnimation__WEBPACK_IMPORTED_MODULE_3__["default"], {
    items: dayObj.posts,
    link: {
      content: dayObj.title,
      href: "#",
      title: dayObj.title,
      onClick: loadPosts
    },
    expand: expand,
    initialExpand: dayObj.expand,
    loading: false,
    rootLink: {
      ...dayObj,
      title: dayObj.title,
      onClick: loadPosts
    },
    showToggleSymbol: true,
    subListCustomClass: "posts"
  }, item => (0,react__WEBPACK_IMPORTED_MODULE_0__.createElement)("li", {
    key: item.ID
  }, (0,react__WEBPACK_IMPORTED_MODULE_0__.createElement)(_DisplayPost__WEBPACK_IMPORTED_MODULE_2__["default"], {
    post: item
  })));
};
/* harmony default export */ const __WEBPACK_DEFAULT_EXPORT__ = (DisplayDay);

/***/ }),

/***/ "./src/components/frontend/components/displayers/DisplayMonth.js":
/*!***********************************************************************!*\
  !*** ./src/components/frontend/components/displayers/DisplayMonth.js ***!
  \***********************************************************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "default": () => (__WEBPACK_DEFAULT_EXPORT__)
/* harmony export */ });
/* harmony import */ var react__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! react */ "react");
/* harmony import */ var react__WEBPACK_IMPORTED_MODULE_0___default = /*#__PURE__*/__webpack_require__.n(react__WEBPACK_IMPORTED_MODULE_0__);
/* harmony import */ var _wordpress_element__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! @wordpress/element */ "@wordpress/element");
/* harmony import */ var _wordpress_element__WEBPACK_IMPORTED_MODULE_1___default = /*#__PURE__*/__webpack_require__.n(_wordpress_element__WEBPACK_IMPORTED_MODULE_1__);
/* harmony import */ var _context_ConfigContext__WEBPACK_IMPORTED_MODULE_2__ = __webpack_require__(/*! ../../context/ConfigContext */ "./src/components/frontend/context/ConfigContext.js");
/* harmony import */ var _hooks_useApi__WEBPACK_IMPORTED_MODULE_3__ = __webpack_require__(/*! ../../hooks/useApi */ "./src/components/frontend/hooks/useApi.js");
/* harmony import */ var _ListWithAnimation__WEBPACK_IMPORTED_MODULE_4__ = __webpack_require__(/*! ../ListWithAnimation */ "./src/components/frontend/components/ListWithAnimation.js");
/* harmony import */ var _DisplayPost__WEBPACK_IMPORTED_MODULE_5__ = __webpack_require__(/*! ./DisplayPost */ "./src/components/frontend/components/displayers/DisplayPost.js");
/* harmony import */ var _DisplayDay__WEBPACK_IMPORTED_MODULE_6__ = __webpack_require__(/*! ./DisplayDay */ "./src/components/frontend/components/displayers/DisplayDay.js");
/* harmony import */ var _wordpress_date__WEBPACK_IMPORTED_MODULE_7__ = __webpack_require__(/*! @wordpress/date */ "@wordpress/date");
/* harmony import */ var _wordpress_date__WEBPACK_IMPORTED_MODULE_7___default = /*#__PURE__*/__webpack_require__.n(_wordpress_date__WEBPACK_IMPORTED_MODULE_7__);

/**
 * WordPress dependencies
 */


/**
 * Internal dependencies
 */






const DisplayMonth = ({
  monthObj,
  year
}) => {
  const {
    config
  } = (0,_wordpress_element__WEBPACK_IMPORTED_MODULE_1__.useContext)(_context_ConfigContext__WEBPACK_IMPORTED_MODULE_2__.ConfigContext);
  const {
    loading,
    data: apiData,
    apiClient
  } = (0,_hooks_useApi__WEBPACK_IMPORTED_MODULE_3__["default"])(`/jalw/v1/archive/${year}/${monthObj.month}`);
  const [expand, setExpand] = (0,_wordpress_element__WEBPACK_IMPORTED_MODULE_1__.useState)(false);
  const loadPosts = async event => {
    event.preventDefault();
    if (!apiData || !Array.isArray(apiData.posts)) {
      const dataWasLoaded = await apiClient(config);
      setExpand(dataWasLoaded);
    } else {
      setExpand(!expand);
    }
  };
  const handleLink = config.only_sym_link || !config.showpost ? () => true : loadPosts;
  let linkContent = monthObj.title;
  if (config.showcount === true) {
    linkContent = `${monthObj.title} (${monthObj.posts})`;
  }
  (0,_wordpress_element__WEBPACK_IMPORTED_MODULE_1__.useEffect)(() => {
    if (expand && !loading && (!apiData || !Array.isArray(apiData.posts))) {
      apiClient(config);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [expand]);
  const subListCustomClass = config.show_day_archive ? 'jawl_days' : 'jaw_posts';
  let items;
  if (apiData && apiData.posts) {
    items = config.show_day_archive ? groupPostsByDay(config, apiData.posts) : apiData.posts;
  } else {
    items = [];
  }
  return (0,react__WEBPACK_IMPORTED_MODULE_0__.createElement)(_ListWithAnimation__WEBPACK_IMPORTED_MODULE_4__["default"], {
    items: items,
    link: {
      content: linkContent,
      href: monthObj.permalink,
      title: monthObj.title,
      onClick: handleLink
    },
    expand: expand,
    initialExpand: monthObj.expand,
    loading: loading,
    rootLink: {
      ...monthObj,
      onClick: loadPosts
    },
    showToggleSymbol: config.showpost,
    subListCustomClass: subListCustomClass
  }, item => config.show_day_archive ? (0,react__WEBPACK_IMPORTED_MODULE_0__.createElement)(_DisplayDay__WEBPACK_IMPORTED_MODULE_6__["default"], {
    key: item.ID,
    dayObj: item
  }) : (0,react__WEBPACK_IMPORTED_MODULE_0__.createElement)("li", {
    key: item.ID
  }, (0,react__WEBPACK_IMPORTED_MODULE_0__.createElement)(_DisplayPost__WEBPACK_IMPORTED_MODULE_5__["default"], {
    post: item
  })));
};
const groupPostsByDay = (config, posts) => {
  if (!posts) return [];
  const groupedByDays = posts.reduce((acc, post) => {
    const day = (0,_wordpress_date__WEBPACK_IMPORTED_MODULE_7__.dateI18n)('d', post.post_date);
    if (!acc[day]) {
      acc[day] = {
        ID: day,
        title: day,
        permalink: '#',
        expand: config.expand === 'all',
        posts: [],
        onClick: () => false
      };
    }
    acc[day].posts.push(post);
    return acc;
  }, {});
  const sortedKeys = Object.keys(groupedByDays).sort((a, b) => a - b);
  const groupedAndSorted = {};
  sortedKeys.forEach(key => {
    groupedAndSorted[key] = groupedByDays[key];
  });
  return Object.values(groupedAndSorted);
};
/* harmony default export */ const __WEBPACK_DEFAULT_EXPORT__ = (DisplayMonth);

/***/ }),

/***/ "./src/components/frontend/components/displayers/DisplayPost.js":
/*!**********************************************************************!*\
  !*** ./src/components/frontend/components/displayers/DisplayPost.js ***!
  \**********************************************************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "default": () => (__WEBPACK_DEFAULT_EXPORT__)
/* harmony export */ });
/* harmony import */ var react__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! react */ "react");
/* harmony import */ var react__WEBPACK_IMPORTED_MODULE_0___default = /*#__PURE__*/__webpack_require__.n(react__WEBPACK_IMPORTED_MODULE_0__);
/* harmony import */ var _wordpress_element__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! @wordpress/element */ "@wordpress/element");
/* harmony import */ var _wordpress_element__WEBPACK_IMPORTED_MODULE_1___default = /*#__PURE__*/__webpack_require__.n(_wordpress_element__WEBPACK_IMPORTED_MODULE_1__);
/* harmony import */ var _wordpress_date__WEBPACK_IMPORTED_MODULE_2__ = __webpack_require__(/*! @wordpress/date */ "@wordpress/date");
/* harmony import */ var _wordpress_date__WEBPACK_IMPORTED_MODULE_2___default = /*#__PURE__*/__webpack_require__.n(_wordpress_date__WEBPACK_IMPORTED_MODULE_2__);
/* harmony import */ var _context_ConfigContext__WEBPACK_IMPORTED_MODULE_3__ = __webpack_require__(/*! ../../context/ConfigContext */ "./src/components/frontend/context/ConfigContext.js");

/**
 * WordPress dependencies
 */



/**
 * Internal dependencies
 */

const DisplayPost = ({
  post
}) => {
  const {
    config
  } = (0,_wordpress_element__WEBPACK_IMPORTED_MODULE_1__.useContext)(_context_ConfigContext__WEBPACK_IMPORTED_MODULE_3__.ConfigContext);
  const dateSettings = (0,_wordpress_date__WEBPACK_IMPORTED_MODULE_2__.getSettings)();
  return (0,react__WEBPACK_IMPORTED_MODULE_0__.createElement)("a", {
    href: post.permalink,
    title: post.post_title
  }, post.post_title, config.show_post_date ? (0,react__WEBPACK_IMPORTED_MODULE_0__.createElement)("span", {
    className: "post-date"
  }, (0,_wordpress_date__WEBPACK_IMPORTED_MODULE_2__.dateI18n)(dateSettings?.formats?.date, post.post_date)) : '');
};
/* harmony default export */ const __WEBPACK_DEFAULT_EXPORT__ = (DisplayPost);

/***/ }),

/***/ "./src/components/frontend/components/displayers/DisplayYear.js":
/*!**********************************************************************!*\
  !*** ./src/components/frontend/components/displayers/DisplayYear.js ***!
  \**********************************************************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "default": () => (__WEBPACK_DEFAULT_EXPORT__)
/* harmony export */ });
/* harmony import */ var react__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! react */ "react");
/* harmony import */ var react__WEBPACK_IMPORTED_MODULE_0___default = /*#__PURE__*/__webpack_require__.n(react__WEBPACK_IMPORTED_MODULE_0__);
/* harmony import */ var _wordpress_element__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! @wordpress/element */ "@wordpress/element");
/* harmony import */ var _wordpress_element__WEBPACK_IMPORTED_MODULE_1___default = /*#__PURE__*/__webpack_require__.n(_wordpress_element__WEBPACK_IMPORTED_MODULE_1__);
/* harmony import */ var _context_ConfigContext__WEBPACK_IMPORTED_MODULE_2__ = __webpack_require__(/*! ../../context/ConfigContext */ "./src/components/frontend/context/ConfigContext.js");
/* harmony import */ var _DisplayMonth__WEBPACK_IMPORTED_MODULE_3__ = __webpack_require__(/*! ./DisplayMonth */ "./src/components/frontend/components/displayers/DisplayMonth.js");
/* harmony import */ var _hooks_useApi__WEBPACK_IMPORTED_MODULE_4__ = __webpack_require__(/*! ../../hooks/useApi */ "./src/components/frontend/hooks/useApi.js");
/* harmony import */ var _ListWithAnimation__WEBPACK_IMPORTED_MODULE_5__ = __webpack_require__(/*! ../ListWithAnimation */ "./src/components/frontend/components/ListWithAnimation.js");

/**
 * WordPress dependencies
 */


/**
 * Internal dependencies
 */




const DisplayYear = ({
  yearObj
}) => {
  const {
    config
  } = (0,_wordpress_element__WEBPACK_IMPORTED_MODULE_1__.useContext)(_context_ConfigContext__WEBPACK_IMPORTED_MODULE_2__.ConfigContext);
  const {
    loading,
    data: apiData,
    apiClient
  } = (0,_hooks_useApi__WEBPACK_IMPORTED_MODULE_4__["default"])(`/jalw/v1/archive/${yearObj.year}`);
  const [expand, setExpand] = (0,_wordpress_element__WEBPACK_IMPORTED_MODULE_1__.useState)(false);
  const loadMonths = async event => {
    event.preventDefault();
    if (!apiData || !Array.isArray(apiData.months)) {
      const dataWasLoaded = await apiClient(config);
      setExpand(dataWasLoaded);
    } else {
      setExpand(!expand);
    }
  };

  // If this option is enabled, then the year link will only expand.
  const handleLink = config.only_sym_link ? () => true : loadMonths;
  let linkContent = yearObj.year;
  if (config.showcount === true) {
    linkContent = `${yearObj.year} (${yearObj.posts})`;
  }
  (0,_wordpress_element__WEBPACK_IMPORTED_MODULE_1__.useEffect)(() => {
    if (expand && !loading && (!apiData || !Array.isArray(apiData.months))) {
      apiClient(config);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [expand]);
  return (0,react__WEBPACK_IMPORTED_MODULE_0__.createElement)(_ListWithAnimation__WEBPACK_IMPORTED_MODULE_5__["default"], {
    items: apiData ? apiData.months : [],
    link: {
      content: linkContent,
      href: yearObj.permalink,
      title: yearObj.title,
      onClick: handleLink
    },
    expand: expand,
    initialExpand: yearObj.expand,
    loading: loading,
    rootLink: {
      ...yearObj,
      onClick: loadMonths
    },
    showToggleSymbol: true,
    subListCustomClass: "jaw_months"
  }, item => (0,react__WEBPACK_IMPORTED_MODULE_0__.createElement)(_DisplayMonth__WEBPACK_IMPORTED_MODULE_3__["default"], {
    key: yearObj.year + item.month,
    year: yearObj.year,
    monthObj: item
  }));
};
/* harmony default export */ const __WEBPACK_DEFAULT_EXPORT__ = (DisplayYear);

/***/ }),

/***/ "./src/components/frontend/context/ConfigContext.js":
/*!**********************************************************!*\
  !*** ./src/components/frontend/context/ConfigContext.js ***!
  \**********************************************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   ConfigContext: () => (/* binding */ ConfigContext),
/* harmony export */   ConfigProvider: () => (/* binding */ ConfigProvider),
/* harmony export */   defaultConfig: () => (/* binding */ defaultConfig)
/* harmony export */ });
/* harmony import */ var react__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! react */ "react");
/* harmony import */ var react__WEBPACK_IMPORTED_MODULE_0___default = /*#__PURE__*/__webpack_require__.n(react__WEBPACK_IMPORTED_MODULE_0__);
/* harmony import */ var _wordpress_element__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! @wordpress/element */ "@wordpress/element");
/* harmony import */ var _wordpress_element__WEBPACK_IMPORTED_MODULE_1___default = /*#__PURE__*/__webpack_require__.n(_wordpress_element__WEBPACK_IMPORTED_MODULE_1__);
/* harmony import */ var _hooks_useAnimation__WEBPACK_IMPORTED_MODULE_2__ = __webpack_require__(/*! ../hooks/useAnimation */ "./src/components/frontend/hooks/useAnimation.js");

/**
 * WordPress dependencies
 */


const defaultConfig = {
  title: '',
  symbol: '0',
  effect: 'none',
  month_format: 'full',
  expand: 'none',
  showcount: false,
  showpost: false,
  sortpost: 'id_asc',
  show_post_date: false,
  show_day_archive: false,
  hide_from_year: null,
  onlycategory: null,
  only_sym_link: false,
  accordion: false,
  include_or_exclude: 'include',
  categories: [],
  currentPost: null
};
const ConfigContext = (0,_wordpress_element__WEBPACK_IMPORTED_MODULE_1__.createContext)(defaultConfig);
const ConfigProvider = ({
  attributes,
  children
}) => {
  const initialConfig = {
    ...defaultConfig,
    ...attributes
  };
  const [config, updateContextConfig] = (0,_wordpress_element__WEBPACK_IMPORTED_MODULE_1__.useState)(initialConfig);
  const setConfig = newConfig => {
    const parsedConfig = {
      ...newConfig
    };

    /* global jalwCurrentPost */
    if (typeof jalwCurrentPost !== 'undefined') {
      parsedConfig.currentPost = jalwCurrentPost;
    }
    parsedConfig.accordion = !!parseInt(parsedConfig.accordion, 10);
    parsedConfig.showcount = !!parseInt(parsedConfig.showcount, 10);
    parsedConfig.showpost = !!parseInt(parsedConfig.showpost, 10);
    parsedConfig.show_post_date = !!parseInt(parsedConfig.show_post_date, 10);
    parsedConfig.only_sym_link = !!parseInt(parsedConfig.only_sym_link, 10);
    parsedConfig.show_day_archive = !!parseInt(parsedConfig.show_day_archive, 10);
    updateContextConfig(prevState => ({
      ...prevState,
      ...parsedConfig
    }));
  };
  const {
    animationFunction,
    hideOpenedLists
  } = (0,_hooks_useAnimation__WEBPACK_IMPORTED_MODULE_2__["default"])(config.effect);
  (0,_wordpress_element__WEBPACK_IMPORTED_MODULE_1__.useEffect)(() => {
    setConfig(attributes);
  }, [attributes]);
  return (0,react__WEBPACK_IMPORTED_MODULE_0__.createElement)(ConfigContext.Provider, {
    value: {
      config,
      setConfig,
      animationFunction,
      hideOpenedLists
    }
  }, children);
};

/***/ }),

/***/ "./src/components/frontend/hooks/useAnimation.js":
/*!*******************************************************!*\
  !*** ./src/components/frontend/hooks/useAnimation.js ***!
  \*******************************************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "default": () => (/* binding */ useAnimation)
/* harmony export */ });
/* harmony import */ var _wordpress_element__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! @wordpress/element */ "@wordpress/element");
/* harmony import */ var _wordpress_element__WEBPACK_IMPORTED_MODULE_0___default = /*#__PURE__*/__webpack_require__.n(_wordpress_element__WEBPACK_IMPORTED_MODULE_0__);
/**
 * WordPress dependencies
 */

function useAnimation(effect) {
  const supportsRequestAnimation = typeof window.requestAnimationFrame === 'function';
  const fadeIn = (element, duration = 500) => {
    element.style.removeProperty('display');
    let display = window.getComputedStyle(element).display;
    if (display === 'none') {
      display = 'block';
    }
    element.style.display = display;
    element.style.opacity = 0;
    let last = +new Date();
    const tick = function () {
      element.style.opacity = +element.style.opacity + (new Date() - last) / duration;
      last = +new Date();
      if (+element.style.opacity < 1) {
        if (supportsRequestAnimation) window.requestAnimationFrame(tick);else setTimeout(tick, 16);
      }
    };
    tick();
  };
  const fadeOut = (element, duration = 500) => {
    element.style.display = '';
    element.style.opacity = 1;
    let last = +new Date();
    const tick = function () {
      element.style.opacity = Number(+element.style.opacity - (new Date() - last) / duration).toFixed(4);
      last = +new Date();
      if (-element.style.opacity <= 0) {
        if (supportsRequestAnimation) window.requestAnimationFrame(tick);else setTimeout(tick, 16);
      } else {
        element.style.display = 'none';
      }
    };
    tick();
  };
  const fadeToggle = (target, duration = 500) => {
    if (window.getComputedStyle(target).display === 'none') {
      target.classList.remove('jal-hide');
      return fadeIn(target, duration);
    }
    return fadeOut(target, duration);
  };
  const slideUp = (target, duration = 500) => {
    target.style.transitionProperty = 'height, margin, padding';
    target.style.transitionDuration = duration + 'ms';
    target.style.boxSizing = 'border-box';
    target.style.height = target.offsetHeight + 'px';
    target.style.overflow = 'hidden';
    target.style.height = 0;
    target.style.paddingTop = 0;
    target.style.paddingBottom = 0;
    target.style.marginTop = 0;
    target.style.marginBottom = 0;
    window.setTimeout(() => {
      target.style.display = 'none';
      target.style.removeProperty('height');
      target.style.removeProperty('padding-top');
      target.style.removeProperty('padding-bottom');
      target.style.removeProperty('margin-top');
      target.style.removeProperty('margin-bottom');
      target.style.removeProperty('overflow');
      target.style.removeProperty('transition-duration');
      target.style.removeProperty('transition-property');
    }, duration);
  };
  const slideDown = (target, duration = 500) => {
    target.style.removeProperty('display');
    let display = window.getComputedStyle(target).display;
    if (display === 'none') {
      display = 'block';
    }
    target.style.display = display;
    const height = target.offsetHeight;
    target.style.overflow = 'hidden';
    target.style.height = 0;
    target.style.paddingTop = 0;
    target.style.paddingBottom = 0;
    target.style.marginTop = 0;
    target.style.marginBottom = 0;
    target.style.boxSizing = 'border-box';
    target.style.transitionProperty = 'height, margin, padding';
    target.style.transitionDuration = duration + 'ms';
    target.style.height = height + 'px';
    target.style.removeProperty('padding-top');
    target.style.removeProperty('padding-bottom');
    target.style.removeProperty('margin-top');
    target.style.removeProperty('margin-bottom');
    window.setTimeout(() => {
      target.style.removeProperty('height');
      target.style.removeProperty('overflow');
      target.style.removeProperty('transition-duration');
      target.style.removeProperty('transition-property');
    }, duration);
  };
  const slideToggle = (target, duration = 500) => {
    if (window.getComputedStyle(target).display === 'none') {
      return slideDown(target, duration);
    }
    return slideUp(target, duration);
  };
  const showToggle = target => {
    if (window.getComputedStyle(target).display === 'none') {
      target.style.removeProperty('display');
      target.classList.remove('jal-hide');
    } else {
      target.style.display = 'none';
    }
  };
  const hideOpenedLists = listRoot => {
    if (listRoot === undefined) return;
    if (!listRoot.classList.contains('expanded')) return;

    // Expanded siblings
    const expandedSiblings = [...listRoot.parentElement.children].filter(ch => {
      return listRoot !== ch && ch.nodeName.toLowerCase() === 'li' && ch.classList.contains('expanded');
    });
    expandedSiblings.forEach(expandedList => {
      if (expandedList !== listRoot) {
        expandedList.querySelectorAll(':scope > .jaw_symbol').forEach(toggler => toggler.click());
      }
    });
  };
  const [animationFunction, setAnimationFunction] = (0,_wordpress_element__WEBPACK_IMPORTED_MODULE_0__.useState)(null);
  (0,_wordpress_element__WEBPACK_IMPORTED_MODULE_0__.useEffect)(() => {
    setAnimationFunction(() => {
      let animationFn;
      switch (effect) {
        case 'fade':
          animationFn = fadeToggle;
          break;
        case 'slide':
          animationFn = slideToggle;
          break;
        default:
          animationFn = showToggle;
          break;
      }
      return animationFn;
    });

    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [effect]);
  return {
    animationFunction,
    hideOpenedLists
  };
}

/***/ }),

/***/ "./src/components/frontend/hooks/useApi.js":
/*!*************************************************!*\
  !*** ./src/components/frontend/hooks/useApi.js ***!
  \*************************************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "default": () => (/* binding */ useApi)
/* harmony export */ });
/* harmony import */ var _wordpress_element__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! @wordpress/element */ "@wordpress/element");
/* harmony import */ var _wordpress_element__WEBPACK_IMPORTED_MODULE_0___default = /*#__PURE__*/__webpack_require__.n(_wordpress_element__WEBPACK_IMPORTED_MODULE_0__);
/* harmony import */ var _wordpress_api_fetch__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! @wordpress/api-fetch */ "@wordpress/api-fetch");
/* harmony import */ var _wordpress_api_fetch__WEBPACK_IMPORTED_MODULE_1___default = /*#__PURE__*/__webpack_require__.n(_wordpress_api_fetch__WEBPACK_IMPORTED_MODULE_1__);
/**
 * WordPress dependencies
 */



/**
 * Internal dependencies
 *
 * @param {string} url
 */
function useApi(url) {
  const [data, setData] = (0,_wordpress_element__WEBPACK_IMPORTED_MODULE_0__.useState)(null);
  const [error, setError] = (0,_wordpress_element__WEBPACK_IMPORTED_MODULE_0__.useState)(null);
  const [loading, setLoading] = (0,_wordpress_element__WEBPACK_IMPORTED_MODULE_0__.useState)(false);

  /* global jalwCurrentCat, jalwCurrentPost */
  const apiClient = async function (config) {
    setLoading(true);
    const params = new URLSearchParams({
      monthFormat: config.month_format,
      expand: config.expand
    });
    if (typeof jalwCurrentCat !== 'undefined' && config.onlycategory > 0) {
      params.append('onlycats', jalwCurrentCat);
    }
    if (config.categories) {
      params.append('exclusionType', config.include_or_exclude);
      params.append('cats', config.categories);
    }
    if (typeof jalwCurrentPost !== 'undefined') {
      if (jalwCurrentPost.month) {
        params.append('postMonth', jalwCurrentPost.month);
      }
      if (jalwCurrentPost.year) {
        params.append('postYear', jalwCurrentPost.year);
      }
    }

    // Checks if it's a post list request.
    if (config.showpost === true && /\/archive\/\d+\/\d+/.test(url)) {
      params.append('sort', config.sortpost);
    }
    return _wordpress_api_fetch__WEBPACK_IMPORTED_MODULE_1___default()({
      path: `${url}?${params.toString()}`
    }).then(response => {
      setData(response);
      setLoading(false);
      return true;
    }).catch(e => {
      setError(e);
      setLoading(false);
      return false;
    });
  };
  return {
    apiClient,
    data,
    error,
    loading,
    setLoading
  };
}

/***/ }),

/***/ "./src/components/frontend/hooks/useFrontend.js":
/*!******************************************************!*\
  !*** ./src/components/frontend/hooks/useFrontend.js ***!
  \******************************************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   useSymbol: () => (/* binding */ useSymbol)
/* harmony export */ });
function useSymbol(symbol) {
  let collapseSymbol = '';
  let expandSymbol = '';
  switch (symbol.toString()) {
    case '1':
      collapseSymbol = '▼';
      expandSymbol = '►';
      break;
    case '2':
      collapseSymbol = '(–)';
      expandSymbol = '(+)';
      break;
    case '3':
      collapseSymbol = '[–]';
      expandSymbol = '[+]';
      break;
  }
  return {
    collapseSymbol,
    expandSymbol
  };
}

/***/ }),

/***/ "./src/edit.js":
/*!*********************!*\
  !*** ./src/edit.js ***!
  \*********************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "default": () => (/* binding */ Edit)
/* harmony export */ });
/* harmony import */ var react__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! react */ "react");
/* harmony import */ var react__WEBPACK_IMPORTED_MODULE_0___default = /*#__PURE__*/__webpack_require__.n(react__WEBPACK_IMPORTED_MODULE_0__);
/* harmony import */ var _wordpress_i18n__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! @wordpress/i18n */ "@wordpress/i18n");
/* harmony import */ var _wordpress_i18n__WEBPACK_IMPORTED_MODULE_1___default = /*#__PURE__*/__webpack_require__.n(_wordpress_i18n__WEBPACK_IMPORTED_MODULE_1__);
/* harmony import */ var _wordpress_block_editor__WEBPACK_IMPORTED_MODULE_2__ = __webpack_require__(/*! @wordpress/block-editor */ "@wordpress/block-editor");
/* harmony import */ var _wordpress_block_editor__WEBPACK_IMPORTED_MODULE_2___default = /*#__PURE__*/__webpack_require__.n(_wordpress_block_editor__WEBPACK_IMPORTED_MODULE_2__);
/* harmony import */ var _wordpress_components__WEBPACK_IMPORTED_MODULE_3__ = __webpack_require__(/*! @wordpress/components */ "@wordpress/components");
/* harmony import */ var _wordpress_components__WEBPACK_IMPORTED_MODULE_3___default = /*#__PURE__*/__webpack_require__.n(_wordpress_components__WEBPACK_IMPORTED_MODULE_3__);
/* harmony import */ var _components_admin_CategoryPicker__WEBPACK_IMPORTED_MODULE_4__ = __webpack_require__(/*! ./components/admin/CategoryPicker */ "./src/components/admin/CategoryPicker.js");
/* harmony import */ var _components_frontend_JsArchiveList__WEBPACK_IMPORTED_MODULE_5__ = __webpack_require__(/*! ./components/frontend/JsArchiveList */ "./src/components/frontend/JsArchiveList.js");
/* harmony import */ var _components_frontend_context_ConfigContext__WEBPACK_IMPORTED_MODULE_6__ = __webpack_require__(/*! ./components/frontend/context/ConfigContext */ "./src/components/frontend/context/ConfigContext.js");
/* harmony import */ var _editor_scss__WEBPACK_IMPORTED_MODULE_7__ = __webpack_require__(/*! ./editor.scss */ "./src/editor.scss");

/**
 * WordPress dependencies
 */




/**
 * Internal dependencies
 */




function Edit({
  attributes,
  setAttributes
}) {
  const categories = Array.isArray(attributes.categories) ? attributes.categories : [];
  return (0,react__WEBPACK_IMPORTED_MODULE_0__.createElement)("div", {
    ...(0,_wordpress_block_editor__WEBPACK_IMPORTED_MODULE_2__.useBlockProps)()
  }, (0,react__WEBPACK_IMPORTED_MODULE_0__.createElement)(_components_frontend_context_ConfigContext__WEBPACK_IMPORTED_MODULE_6__.ConfigProvider, {
    attributes: attributes
  }, (0,react__WEBPACK_IMPORTED_MODULE_0__.createElement)(_components_frontend_JsArchiveList__WEBPACK_IMPORTED_MODULE_5__["default"], null)), (0,react__WEBPACK_IMPORTED_MODULE_0__.createElement)(_wordpress_block_editor__WEBPACK_IMPORTED_MODULE_2__.InspectorControls, {
    key: "setting"
  }, (0,react__WEBPACK_IMPORTED_MODULE_0__.createElement)("div", {
    className: "jalw-controls"
  }, (0,react__WEBPACK_IMPORTED_MODULE_0__.createElement)(_wordpress_components__WEBPACK_IMPORTED_MODULE_3__.Panel, null, (0,react__WEBPACK_IMPORTED_MODULE_0__.createElement)(_wordpress_components__WEBPACK_IMPORTED_MODULE_3__.PanelBody, {
    title: (0,_wordpress_i18n__WEBPACK_IMPORTED_MODULE_1__.__)("General options", "jalw"),
    initialOpen: true
  }, (0,react__WEBPACK_IMPORTED_MODULE_0__.createElement)(_wordpress_components__WEBPACK_IMPORTED_MODULE_3__.TextControl, {
    label: (0,_wordpress_i18n__WEBPACK_IMPORTED_MODULE_1__.__)("Title", "jalw"),
    value: attributes.title,
    onChange: val => setAttributes({
      title: val
    })
  }), (0,react__WEBPACK_IMPORTED_MODULE_0__.createElement)(_wordpress_components__WEBPACK_IMPORTED_MODULE_3__.SelectControl, {
    label: (0,_wordpress_i18n__WEBPACK_IMPORTED_MODULE_1__.__)("Trigger Symbol", "jalw"),
    value: attributes.symbol,
    onChange: val => setAttributes({
      symbol: val
    }),
    options: [{
      value: "0",
      label: (0,_wordpress_i18n__WEBPACK_IMPORTED_MODULE_1__.__)("Empty Space", "jalw")
    }, {
      value: "1",
      label: "► ▼"
    }, {
      value: "2",
      label: "(+) (–)"
    }, {
      value: "3",
      label: "[+] [–]"
    }]
  }), (0,react__WEBPACK_IMPORTED_MODULE_0__.createElement)(_wordpress_components__WEBPACK_IMPORTED_MODULE_3__.SelectControl, {
    label: (0,_wordpress_i18n__WEBPACK_IMPORTED_MODULE_1__.__)("Effect", "jalw"),
    value: attributes.effect,
    onChange: val => setAttributes({
      effect: val
    }),
    options: [{
      value: "none",
      label: (0,_wordpress_i18n__WEBPACK_IMPORTED_MODULE_1__.__)("None", "jalw")
    }, {
      value: "slide",
      label: (0,_wordpress_i18n__WEBPACK_IMPORTED_MODULE_1__.__)("Slide( Accordion )", "jalw")
    }, {
      value: "fade",
      label: (0,_wordpress_i18n__WEBPACK_IMPORTED_MODULE_1__.__)("Fade", "jalw")
    }]
  }), (0,react__WEBPACK_IMPORTED_MODULE_0__.createElement)(_wordpress_components__WEBPACK_IMPORTED_MODULE_3__.SelectControl, {
    label: (0,_wordpress_i18n__WEBPACK_IMPORTED_MODULE_1__.__)("Month Format", "jalw"),
    value: attributes.month_format,
    onChange: val => setAttributes({
      month_format: val
    }),
    options: [{
      value: "full",
      label: (0,_wordpress_i18n__WEBPACK_IMPORTED_MODULE_1__.__)("Full Name( January )", "jalw")
    }, {
      value: "short",
      label: (0,_wordpress_i18n__WEBPACK_IMPORTED_MODULE_1__.__)("Short Name( Jan )", "jalw")
    }, {
      value: "number",
      label: (0,_wordpress_i18n__WEBPACK_IMPORTED_MODULE_1__.__)("Number( 01 )", "jalw")
    }]
  }), (0,react__WEBPACK_IMPORTED_MODULE_0__.createElement)(_wordpress_components__WEBPACK_IMPORTED_MODULE_3__.SelectControl, {
    label: (0,_wordpress_i18n__WEBPACK_IMPORTED_MODULE_1__.__)("Expand", "jalw"),
    value: attributes.expand,
    onChange: val => setAttributes({
      expand: val
    }),
    options: [{
      value: "",
      label: (0,_wordpress_i18n__WEBPACK_IMPORTED_MODULE_1__.__)("None", "jalw")
    }, {
      value: "all",
      label: (0,_wordpress_i18n__WEBPACK_IMPORTED_MODULE_1__.__)("All", "jalw")
    }, {
      value: "current",
      label: (0,_wordpress_i18n__WEBPACK_IMPORTED_MODULE_1__.__)("Current or post date", "jalw")
    }, {
      value: "current_post",
      label: (0,_wordpress_i18n__WEBPACK_IMPORTED_MODULE_1__.__)("Only post date", "jalw")
    }, {
      value: "current_date",
      label: (0,_wordpress_i18n__WEBPACK_IMPORTED_MODULE_1__.__)("Only current date", "jalw")
    }]
  }), (0,react__WEBPACK_IMPORTED_MODULE_0__.createElement)(_wordpress_components__WEBPACK_IMPORTED_MODULE_3__.TextControl, {
    type: "number",
    step: "1",
    label: (0,_wordpress_i18n__WEBPACK_IMPORTED_MODULE_1__.__)("Hide years from before", "jalw"),
    value: attributes.hide_from_year,
    onChange: val => setAttributes({
      hide_from_year: val
    }),
    placeholder: (0,_wordpress_i18n__WEBPACK_IMPORTED_MODULE_1__.__)("Leave empty to show all years", "jalw")
  }), (0,react__WEBPACK_IMPORTED_MODULE_0__.createElement)(_wordpress_components__WEBPACK_IMPORTED_MODULE_3__.SelectControl, {
    label: (0,_wordpress_i18n__WEBPACK_IMPORTED_MODULE_1__.__)("Post type", "jalw"),
    value: attributes.expand,
    onChange: val => setAttributes({
      expand: val
    }),
    options: []
  }))), (0,react__WEBPACK_IMPORTED_MODULE_0__.createElement)(_wordpress_components__WEBPACK_IMPORTED_MODULE_3__.Panel, null, (0,react__WEBPACK_IMPORTED_MODULE_0__.createElement)(_wordpress_components__WEBPACK_IMPORTED_MODULE_3__.PanelBody, {
    title: (0,_wordpress_i18n__WEBPACK_IMPORTED_MODULE_1__.__)("Extra options", "jalw"),
    initialOpen: false
  }, (0,react__WEBPACK_IMPORTED_MODULE_0__.createElement)(_wordpress_components__WEBPACK_IMPORTED_MODULE_3__.PanelRow, null, (0,react__WEBPACK_IMPORTED_MODULE_0__.createElement)(_wordpress_components__WEBPACK_IMPORTED_MODULE_3__.CheckboxControl, {
    label: (0,_wordpress_i18n__WEBPACK_IMPORTED_MODULE_1__.__)("Show days inside month list", "jalw"),
    checked: attributes.show_day_archive,
    onChange: val => setAttributes({
      show_day_archive: val
    })
  })), (0,react__WEBPACK_IMPORTED_MODULE_0__.createElement)(_wordpress_components__WEBPACK_IMPORTED_MODULE_3__.PanelRow, null, (0,react__WEBPACK_IMPORTED_MODULE_0__.createElement)(_wordpress_components__WEBPACK_IMPORTED_MODULE_3__.CheckboxControl, {
    label: (0,_wordpress_i18n__WEBPACK_IMPORTED_MODULE_1__.__)("Show number of posts", "jalw"),
    checked: attributes.showcount,
    onChange: val => setAttributes({
      showcount: val
    })
  })), (0,react__WEBPACK_IMPORTED_MODULE_0__.createElement)(_wordpress_components__WEBPACK_IMPORTED_MODULE_3__.PanelRow, null, (0,react__WEBPACK_IMPORTED_MODULE_0__.createElement)(_wordpress_components__WEBPACK_IMPORTED_MODULE_3__.CheckboxControl, {
    label: (0,_wordpress_i18n__WEBPACK_IMPORTED_MODULE_1__.__)("Show only posts from selected category in a category page", "jalw"),
    checked: attributes.onlycategory,
    onChange: val => setAttributes({
      onlycategory: val
    })
  })), (0,react__WEBPACK_IMPORTED_MODULE_0__.createElement)(_wordpress_components__WEBPACK_IMPORTED_MODULE_3__.PanelRow, null, (0,react__WEBPACK_IMPORTED_MODULE_0__.createElement)(_wordpress_components__WEBPACK_IMPORTED_MODULE_3__.CheckboxControl, {
    label: (0,_wordpress_i18n__WEBPACK_IMPORTED_MODULE_1__.__)("Only expand / reduce by clicking the symbol", "jalw"),
    checked: attributes.only_sym_link,
    onChange: val => setAttributes({
      only_sym_link: val
    })
  })), (0,react__WEBPACK_IMPORTED_MODULE_0__.createElement)(_wordpress_components__WEBPACK_IMPORTED_MODULE_3__.PanelRow, null, (0,react__WEBPACK_IMPORTED_MODULE_0__.createElement)(_wordpress_components__WEBPACK_IMPORTED_MODULE_3__.CheckboxControl, {
    label: (0,_wordpress_i18n__WEBPACK_IMPORTED_MODULE_1__.__)("Only expand one at a the same time (accordion effect)", "jalw"),
    checked: attributes.accordion,
    onChange: val => setAttributes({
      accordion: val
    })
  })))), (0,react__WEBPACK_IMPORTED_MODULE_0__.createElement)(_wordpress_components__WEBPACK_IMPORTED_MODULE_3__.Panel, null, (0,react__WEBPACK_IMPORTED_MODULE_0__.createElement)(_wordpress_components__WEBPACK_IMPORTED_MODULE_3__.PanelBody, {
    title: (0,_wordpress_i18n__WEBPACK_IMPORTED_MODULE_1__.__)("Display posts", "jalw"),
    initialOpen: false
  }, (0,react__WEBPACK_IMPORTED_MODULE_0__.createElement)(_wordpress_components__WEBPACK_IMPORTED_MODULE_3__.PanelRow, null, (0,react__WEBPACK_IMPORTED_MODULE_0__.createElement)(_wordpress_components__WEBPACK_IMPORTED_MODULE_3__.CheckboxControl, {
    label: (0,_wordpress_i18n__WEBPACK_IMPORTED_MODULE_1__.__)("Show posts under months", "jalw"),
    checked: attributes.showpost,
    onChange: val => setAttributes({
      showpost: val
    })
  })), attributes.showpost ? (0,react__WEBPACK_IMPORTED_MODULE_0__.createElement)(react__WEBPACK_IMPORTED_MODULE_0__.Fragment, null, (0,react__WEBPACK_IMPORTED_MODULE_0__.createElement)(_wordpress_components__WEBPACK_IMPORTED_MODULE_3__.PanelRow, null, (0,react__WEBPACK_IMPORTED_MODULE_0__.createElement)(_wordpress_components__WEBPACK_IMPORTED_MODULE_3__.CheckboxControl, {
    label: (0,_wordpress_i18n__WEBPACK_IMPORTED_MODULE_1__.__)("Show post date next to post title", "jalw"),
    checked: attributes.show_post_date,
    onChange: val => setAttributes({
      show_post_date: val
    })
  })), (0,react__WEBPACK_IMPORTED_MODULE_0__.createElement)(_wordpress_components__WEBPACK_IMPORTED_MODULE_3__.PanelRow, null, (0,react__WEBPACK_IMPORTED_MODULE_0__.createElement)(_wordpress_components__WEBPACK_IMPORTED_MODULE_3__.SelectControl, {
    label: (0,_wordpress_i18n__WEBPACK_IMPORTED_MODULE_1__.__)("Sort posts by", "jalw"),
    value: attributes.sortpost,
    onChange: val => setAttributes({
      sortpost: val
    }),
    options: [{
      value: "id_asc",
      label: (0,_wordpress_i18n__WEBPACK_IMPORTED_MODULE_1__.__)("ID (ASC)", "jalw")
    }, {
      value: "id_desc",
      label: (0,_wordpress_i18n__WEBPACK_IMPORTED_MODULE_1__.__)("ID (DESC)", "jalw")
    }, {
      value: "name_asc",
      label: (0,_wordpress_i18n__WEBPACK_IMPORTED_MODULE_1__.__)("Name (ASC)", "jalw")
    }, {
      value: "name_desc",
      label: (0,_wordpress_i18n__WEBPACK_IMPORTED_MODULE_1__.__)("Name (DESC)", "jalw")
    }, {
      value: "date_asc",
      label: (0,_wordpress_i18n__WEBPACK_IMPORTED_MODULE_1__.__)("Date (ASC)", "jalw")
    }, {
      value: "date_desc",
      label: (0,_wordpress_i18n__WEBPACK_IMPORTED_MODULE_1__.__)("Date (DESC)", "jalw")
    }]
  }))) : null)), (0,react__WEBPACK_IMPORTED_MODULE_0__.createElement)(_wordpress_components__WEBPACK_IMPORTED_MODULE_3__.Panel, null, (0,react__WEBPACK_IMPORTED_MODULE_0__.createElement)(_wordpress_components__WEBPACK_IMPORTED_MODULE_3__.PanelBody, {
    title: (0,_wordpress_i18n__WEBPACK_IMPORTED_MODULE_1__.__)("Category management", "jalw"),
    initialOpen: false
  }, (0,react__WEBPACK_IMPORTED_MODULE_0__.createElement)(_wordpress_components__WEBPACK_IMPORTED_MODULE_3__.PanelRow, null, (0,react__WEBPACK_IMPORTED_MODULE_0__.createElement)(_wordpress_components__WEBPACK_IMPORTED_MODULE_3__.RadioControl, {
    label: (0,_wordpress_i18n__WEBPACK_IMPORTED_MODULE_1__.__)("Include or exclude", "jalw"),
    selected: attributes.include_or_exclude,
    options: [{
      label: (0,_wordpress_i18n__WEBPACK_IMPORTED_MODULE_1__.__)("Include the following categories", "jalw"),
      value: "include"
    }, {
      label: (0,_wordpress_i18n__WEBPACK_IMPORTED_MODULE_1__.__)("Exclude the following categories ", "jalw"),
      value: "exclude"
    }],
    onChange: val => setAttributes({
      include_or_exclude: val
    })
  })), (0,react__WEBPACK_IMPORTED_MODULE_0__.createElement)(_wordpress_components__WEBPACK_IMPORTED_MODULE_3__.PanelRow, null, (0,react__WEBPACK_IMPORTED_MODULE_0__.createElement)(_components_admin_CategoryPicker__WEBPACK_IMPORTED_MODULE_4__["default"], {
    selectedCats: categories,
    onSelected: val => setAttributes({
      categories: val
    })
  })))))));
}

/***/ }),

/***/ "./src/index.js":
/*!**********************!*\
  !*** ./src/index.js ***!
  \**********************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

__webpack_require__.r(__webpack_exports__);
/* harmony import */ var _wordpress_blocks__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! @wordpress/blocks */ "@wordpress/blocks");
/* harmony import */ var _wordpress_blocks__WEBPACK_IMPORTED_MODULE_0___default = /*#__PURE__*/__webpack_require__.n(_wordpress_blocks__WEBPACK_IMPORTED_MODULE_0__);
/* harmony import */ var _style_scss__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! ./style.scss */ "./src/style.scss");
/* harmony import */ var _edit__WEBPACK_IMPORTED_MODULE_2__ = __webpack_require__(/*! ./edit */ "./src/edit.js");
/* harmony import */ var _save__WEBPACK_IMPORTED_MODULE_3__ = __webpack_require__(/*! ./save */ "./src/save.js");



/**
 * Internal dependencies
 */



/**
 * Every block starts by registering a new block type definition.
 *
 * @see https://developer.wordpress.org/block-editor/reference-guides/block-api/block-registration/
 */
(0,_wordpress_blocks__WEBPACK_IMPORTED_MODULE_0__.registerBlockType)('js-archive-list/archive-widget', {
  category: 'widgets',
  /**
   * @see ./edit.js
   */
  edit: _edit__WEBPACK_IMPORTED_MODULE_2__["default"],
  /**
   * @see ./save.js
   */
  save: _save__WEBPACK_IMPORTED_MODULE_3__["default"]
});

/***/ }),

/***/ "./src/save.js":
/*!*********************!*\
  !*** ./src/save.js ***!
  \*********************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "default": () => (/* binding */ save)
/* harmony export */ });
function save() {
  return null;
}

/***/ }),

/***/ "./src/editor.scss":
/*!*************************!*\
  !*** ./src/editor.scss ***!
  \*************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

__webpack_require__.r(__webpack_exports__);
// extracted by mini-css-extract-plugin


/***/ }),

/***/ "./src/style.scss":
/*!************************!*\
  !*** ./src/style.scss ***!
  \************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

__webpack_require__.r(__webpack_exports__);
// extracted by mini-css-extract-plugin


/***/ }),

/***/ "react":
/*!************************!*\
  !*** external "React" ***!
  \************************/
/***/ ((module) => {

module.exports = window["React"];

/***/ }),

/***/ "@wordpress/api-fetch":
/*!**********************************!*\
  !*** external ["wp","apiFetch"] ***!
  \**********************************/
/***/ ((module) => {

module.exports = window["wp"]["apiFetch"];

/***/ }),

/***/ "@wordpress/block-editor":
/*!*************************************!*\
  !*** external ["wp","blockEditor"] ***!
  \*************************************/
/***/ ((module) => {

module.exports = window["wp"]["blockEditor"];

/***/ }),

/***/ "@wordpress/blocks":
/*!********************************!*\
  !*** external ["wp","blocks"] ***!
  \********************************/
/***/ ((module) => {

module.exports = window["wp"]["blocks"];

/***/ }),

/***/ "@wordpress/components":
/*!************************************!*\
  !*** external ["wp","components"] ***!
  \************************************/
/***/ ((module) => {

module.exports = window["wp"]["components"];

/***/ }),

/***/ "@wordpress/data":
/*!******************************!*\
  !*** external ["wp","data"] ***!
  \******************************/
/***/ ((module) => {

module.exports = window["wp"]["data"];

/***/ }),

/***/ "@wordpress/date":
/*!******************************!*\
  !*** external ["wp","date"] ***!
  \******************************/
/***/ ((module) => {

module.exports = window["wp"]["date"];

/***/ }),

/***/ "@wordpress/element":
/*!*********************************!*\
  !*** external ["wp","element"] ***!
  \*********************************/
/***/ ((module) => {

module.exports = window["wp"]["element"];

/***/ }),

/***/ "@wordpress/i18n":
/*!******************************!*\
  !*** external ["wp","i18n"] ***!
  \******************************/
/***/ ((module) => {

module.exports = window["wp"]["i18n"];

/***/ })

/******/ 	});
/************************************************************************/
/******/ 	// The module cache
/******/ 	var __webpack_module_cache__ = {};
/******/ 	
/******/ 	// The require function
/******/ 	function __webpack_require__(moduleId) {
/******/ 		// Check if module is in cache
/******/ 		var cachedModule = __webpack_module_cache__[moduleId];
/******/ 		if (cachedModule !== undefined) {
/******/ 			return cachedModule.exports;
/******/ 		}
/******/ 		// Create a new module (and put it into the cache)
/******/ 		var module = __webpack_module_cache__[moduleId] = {
/******/ 			// no module.id needed
/******/ 			// no module.loaded needed
/******/ 			exports: {}
/******/ 		};
/******/ 	
/******/ 		// Execute the module function
/******/ 		__webpack_modules__[moduleId](module, module.exports, __webpack_require__);
/******/ 	
/******/ 		// Return the exports of the module
/******/ 		return module.exports;
/******/ 	}
/******/ 	
/******/ 	// expose the modules object (__webpack_modules__)
/******/ 	__webpack_require__.m = __webpack_modules__;
/******/ 	
/************************************************************************/
/******/ 	/* webpack/runtime/chunk loaded */
/******/ 	(() => {
/******/ 		var deferred = [];
/******/ 		__webpack_require__.O = (result, chunkIds, fn, priority) => {
/******/ 			if(chunkIds) {
/******/ 				priority = priority || 0;
/******/ 				for(var i = deferred.length; i > 0 && deferred[i - 1][2] > priority; i--) deferred[i] = deferred[i - 1];
/******/ 				deferred[i] = [chunkIds, fn, priority];
/******/ 				return;
/******/ 			}
/******/ 			var notFulfilled = Infinity;
/******/ 			for (var i = 0; i < deferred.length; i++) {
/******/ 				var [chunkIds, fn, priority] = deferred[i];
/******/ 				var fulfilled = true;
/******/ 				for (var j = 0; j < chunkIds.length; j++) {
/******/ 					if ((priority & 1 === 0 || notFulfilled >= priority) && Object.keys(__webpack_require__.O).every((key) => (__webpack_require__.O[key](chunkIds[j])))) {
/******/ 						chunkIds.splice(j--, 1);
/******/ 					} else {
/******/ 						fulfilled = false;
/******/ 						if(priority < notFulfilled) notFulfilled = priority;
/******/ 					}
/******/ 				}
/******/ 				if(fulfilled) {
/******/ 					deferred.splice(i--, 1)
/******/ 					var r = fn();
/******/ 					if (r !== undefined) result = r;
/******/ 				}
/******/ 			}
/******/ 			return result;
/******/ 		};
/******/ 	})();
/******/ 	
/******/ 	/* webpack/runtime/compat get default export */
/******/ 	(() => {
/******/ 		// getDefaultExport function for compatibility with non-harmony modules
/******/ 		__webpack_require__.n = (module) => {
/******/ 			var getter = module && module.__esModule ?
/******/ 				() => (module['default']) :
/******/ 				() => (module);
/******/ 			__webpack_require__.d(getter, { a: getter });
/******/ 			return getter;
/******/ 		};
/******/ 	})();
/******/ 	
/******/ 	/* webpack/runtime/define property getters */
/******/ 	(() => {
/******/ 		// define getter functions for harmony exports
/******/ 		__webpack_require__.d = (exports, definition) => {
/******/ 			for(var key in definition) {
/******/ 				if(__webpack_require__.o(definition, key) && !__webpack_require__.o(exports, key)) {
/******/ 					Object.defineProperty(exports, key, { enumerable: true, get: definition[key] });
/******/ 				}
/******/ 			}
/******/ 		};
/******/ 	})();
/******/ 	
/******/ 	/* webpack/runtime/hasOwnProperty shorthand */
/******/ 	(() => {
/******/ 		__webpack_require__.o = (obj, prop) => (Object.prototype.hasOwnProperty.call(obj, prop))
/******/ 	})();
/******/ 	
/******/ 	/* webpack/runtime/make namespace object */
/******/ 	(() => {
/******/ 		// define __esModule on exports
/******/ 		__webpack_require__.r = (exports) => {
/******/ 			if(typeof Symbol !== 'undefined' && Symbol.toStringTag) {
/******/ 				Object.defineProperty(exports, Symbol.toStringTag, { value: 'Module' });
/******/ 			}
/******/ 			Object.defineProperty(exports, '__esModule', { value: true });
/******/ 		};
/******/ 	})();
/******/ 	
/******/ 	/* webpack/runtime/jsonp chunk loading */
/******/ 	(() => {
/******/ 		// no baseURI
/******/ 		
/******/ 		// object to store loaded and loading chunks
/******/ 		// undefined = chunk not loaded, null = chunk preloaded/prefetched
/******/ 		// [resolve, reject, Promise] = chunk loading, 0 = chunk loaded
/******/ 		var installedChunks = {
/******/ 			"index": 0,
/******/ 			"./style-index": 0
/******/ 		};
/******/ 		
/******/ 		// no chunk on demand loading
/******/ 		
/******/ 		// no prefetching
/******/ 		
/******/ 		// no preloaded
/******/ 		
/******/ 		// no HMR
/******/ 		
/******/ 		// no HMR manifest
/******/ 		
/******/ 		__webpack_require__.O.j = (chunkId) => (installedChunks[chunkId] === 0);
/******/ 		
/******/ 		// install a JSONP callback for chunk loading
/******/ 		var webpackJsonpCallback = (parentChunkLoadingFunction, data) => {
/******/ 			var [chunkIds, moreModules, runtime] = data;
/******/ 			// add "moreModules" to the modules object,
/******/ 			// then flag all "chunkIds" as loaded and fire callback
/******/ 			var moduleId, chunkId, i = 0;
/******/ 			if(chunkIds.some((id) => (installedChunks[id] !== 0))) {
/******/ 				for(moduleId in moreModules) {
/******/ 					if(__webpack_require__.o(moreModules, moduleId)) {
/******/ 						__webpack_require__.m[moduleId] = moreModules[moduleId];
/******/ 					}
/******/ 				}
/******/ 				if(runtime) var result = runtime(__webpack_require__);
/******/ 			}
/******/ 			if(parentChunkLoadingFunction) parentChunkLoadingFunction(data);
/******/ 			for(;i < chunkIds.length; i++) {
/******/ 				chunkId = chunkIds[i];
/******/ 				if(__webpack_require__.o(installedChunks, chunkId) && installedChunks[chunkId]) {
/******/ 					installedChunks[chunkId][0]();
/******/ 				}
/******/ 				installedChunks[chunkId] = 0;
/******/ 			}
/******/ 			return __webpack_require__.O(result);
/******/ 		}
/******/ 		
/******/ 		var chunkLoadingGlobal = globalThis["webpackChunkjs_archive_list"] = globalThis["webpackChunkjs_archive_list"] || [];
/******/ 		chunkLoadingGlobal.forEach(webpackJsonpCallback.bind(null, 0));
/******/ 		chunkLoadingGlobal.push = webpackJsonpCallback.bind(null, chunkLoadingGlobal.push.bind(chunkLoadingGlobal));
/******/ 	})();
/******/ 	
/************************************************************************/
/******/ 	
/******/ 	// startup
/******/ 	// Load entry module and return exports
/******/ 	// This entry module depends on other loaded chunks and execution need to be delayed
/******/ 	var __webpack_exports__ = __webpack_require__.O(undefined, ["./style-index"], () => (__webpack_require__("./src/index.js")))
/******/ 	__webpack_exports__ = __webpack_require__.O(__webpack_exports__);
/******/ 	
/******/ })()
;
//# sourceMappingURL=index.js.map