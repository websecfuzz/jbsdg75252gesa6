<?php

namespace CleverReach\WordPress\IntegrationCore\Infrastructure\Interfaces\Required;

use CleverReach\WordPress\IntegrationCore\Infrastructure\Logger\Logger;
use CleverReach\WordPress\IntegrationCore\Infrastructure\ServiceRegister;
use CleverReach\WordPress\IntegrationCore\Infrastructure\Utility\DTO\Options;
use CleverReach\WordPress\IntegrationCore\Infrastructure\Utility\Exceptions\HttpCommunicationException;
use CleverReach\WordPress\IntegrationCore\Infrastructure\Utility\HttpResponse;

/**
 * Class HttpClient
 *
 * @package CleverReach\WordPress\IntegrationCore\Infrastructure\Interfaces\Required
 */
abstract class HttpClient
{
    /**
     * Fully qualified name of this class.
     */
    const CLASS_NAME = __CLASS__;
    /**
     * Unauthorized HTTP status code.
     */
    const HTTP_STATUS_CODE_UNAUTHORIZED = 401;
    /**
     * Forbidden HTTP status code.
     */
    const HTTP_STATUS_CODE_FORBIDDEN = 403;
    /**
     * Not found HTTP status code.
     */
    const HTTP_STATUS_CODE_NOT_FOUND = 404;
    /**
     * HTTP GET method.
     */
    const HTTP_METHOD_GET = 'GET';
    /**
     * HTTP POST method.
     */
    const HTTP_METHOD_POST = 'POST';
    /**
     * HTTP PUT method.
     */
    const HTTP_METHOD_PUT = 'PUT';
    /**
     * HTTP DELETE method.
     */
    const HTTP_METHOD_DELETE = 'DELETE';
    /**
     * HTTP PATCH method.
     */
    const HTTP_METHOD_PATCH = 'PATCH';
    /**
     * An array of additional HTTP configuration options.
     *
     * @var array
     */
    private $httpConfigurationOptions;

    /**
     * Create, log and send request.
     *
     * @param string $method HTTP method (GET, POST, PUT, DELETE etc.)
     * @param string $url Request URL. Full URL where request should be sent.
     * @param array|null $headers Request headers to send. Key as header name and value as header content.
     * @param string $body Request payload. String data to send request payload in JSON format.
     *
     * @return HttpResponse
     *   Response object.
     * @throws HttpCommunicationException
     */
    public function request($method, $url, $headers = array(), $body = '')
    {
        Logger::logDebug(json_encode(array(
            'Type' => $method,
            'Endpoint' => $url,
            'Headers' => json_encode($headers),
            'Content' => $body
        )));

        /** @var HttpResponse $response */
        $response = $this->sendHttpRequest($method, $url, $headers, $body);

        Logger::logDebug(json_encode(array(
            'ResponseFor' => "{$method} at {$url}",
            'Status' => $response->getStatus(),
            'Headers' => json_encode($response->getHeaders()),
            'Content' => $response->getBody()
        )));

        return $response;
    }

    /**
     * Create, log and send request asynchronously.
     *
     * @param string $method HTTP method (GET, POST, PUT, DELETE etc.)
     * @param string $url Request URL. Full URL where request should be sent.
     * @param array|null $headers Request headers to send. Key as header name and value as header content.
     * @param string $body Request payload. String data to send request payload in JSON format.
     */
    public function requestAsync($method, $url, $headers = array(), $body = '')
    {
        Logger::logDebug(json_encode(array(
            'Type' => $method,
            'Endpoint' => $url,
            'Headers' => $headers,
            'Content' => $body
        )));
        
        $this->sendHttpRequestAsync($method, $url, $headers, $body);
    }

    /**
     * Tries to make a request with provided combinations within integration.
     *
     * @param string $method HTTP method (GET, POST, PUT, DELETE etc.)
     * @param string $url Request URL. Full URL where request should be sent.
     * @param array|null $headers Request headers to send. Key as header name and value as header content.
     * @param string $body Request payload. String data to send as HTTP request payload.
     *
     * @return bool
     *   When request is successful returns true. otherwise false.
     */
    public function autoConfigure($method, $url, $headers = array(), $body = '')
    {
        $passed = $this->isRequestSuccessful($method, $url, $headers, $body);
        if ($passed) {
            return true;
        }

        $domain = parse_url($url, PHP_URL_HOST);
        $combinations = $this->getAdditionalOptions($domain);
        foreach ($combinations as $combination) {
            $this->setAdditionalOptions($domain, $combination);
            $passed = $this->isRequestSuccessful($method, $url, $headers, $body);
            if ($passed) {
                return true;
            }

            $this->resetAdditionalOptions($domain);
        }

        return false;
    }

    /**
     * Get additional options for request
     *
     * @return array|void
     *   All possible combinations for additional curl options.
     */
    protected function getAdditionalOptions($domain)
    {
        if (!$this->httpConfigurationOptions) {
            $options = $this->getConfigService()->getHttpConfigurationOptions($domain);
            $this->httpConfigurationOptions = array();
            foreach ($options as $option) {
                $this->httpConfigurationOptions[$option->getName()] = $option->getValue();
            }
        }

        return $this->httpConfigurationOptions;
    }

    /**
     * Save additional options for request.
     *
     * @param Options[]|null $options Options to save.
     */
    protected function setAdditionalOptions($domain, $options)
    {
        $this->httpConfigurationOptions = null;
        $this->getConfigService()->setHttpConfigurationOptions($domain, $options);
    }

    /**
     * Reset additional options for request to default value
     */
    protected function resetAdditionalOptions($domain)
    {
        $this->httpConfigurationOptions = null;
        $this->getConfigService()->setHttpConfigurationOptions($domain, array());
    }

    /**
     * Tries to make request using provided parameters.
     *
     * @param string $method HTTP method (GET, POST, PUT, DELETE etc.)
     * @param string $url Request URL. Full URL where request should be sent.
     * @param array|null $headers Request headers to send. Key as header name and value as header content.
     * @param string $body Request payload. String data to send request payload in JSON format.
     *
     * @return bool
     *   If request is made successfully returns true, otherwise false.
     *   Response must have 'status' attribute with 'success' value if it is made successfully.
     */
    private function isRequestSuccessful($method, $url, $headers = array(), $body = '')
    {
        try {
            /** @var HttpResponse $response */
            $response = $this->request($method, $url, $headers, $body);
        } catch (HttpCommunicationException $ex) {
            $response = null;
        }

        if ($response !== null) {
            $responseBody = $response->getBody();
            if (!empty($responseBody)) {
                $result = json_decode($responseBody, true);
                if (isset($result['status']) && $result['status'] === 'success') {
                    return true;
                }
            }
        }

        return false;
    }

    /**
     * Create and send request.
     *
     * @param string $method HTTP method (GET, POST, PUT, DELETE etc.)
     * @param string $url Request URL. Full URL where request should be sent.
     * @param array|null $headers Request headers to send. Key as header name and value as header content.
     * @param string $body Request payload. String data to send request payload in JSON format.
     *
     * @return HttpResponse
     *   Http response object.
     * @throws HttpCommunicationException
     *   Only in situation when there is no connection, no response, throw this exception.
     */
    abstract protected function sendHttpRequest($method, $url, $headers = array(), $body = '');

    /**
     * Create and send request asynchronously.
     *
     * @param string $method HTTP method (GET, POST, PUT, DELETE etc.)
     * @param string $url Request URL. Full URL where request should be sent.
     * @param array|null $headers Request headers to send. Key as header name and value as header content.
     * @param string $body Request payload. String data to send request payload in JSON format.
     */
    abstract protected function sendHttpRequestAsync($method, $url, $headers = array(), $body = '');

    /**
     * Gets the configuration service.
     *
     * @return Configuration Configuration service instance.
     */
    protected function getConfigService()
    {
        if (empty($this->configService)) {
            $this->configService = ServiceRegister::getService(Configuration::CLASS_NAME);
        }

        return $this->configService;
    }
}
