<?php
if (!defined('_PS_VERSION_')) {
    exit;
}

class CwCloudEmailPlugin extends Module {
    public function __construct() {
        $this->name = 'cwcloudemailplugin';
        $this->tab = 'emailing';
        $this->version = '1.0.0';
        $this->author = 'Idriss Neumann';
        $this->need_instance = 0;
        $this->ps_versions_compliancy = array('min' => '1.6', 'max' => _PS_VERSION_);
        $this->bootstrap = true;

        parent::__construct();

        $this->displayName = 'CwCloud Email API plugin';
        $this->description = 'Replaces PrestaShop SMTP with the CwCloud email API.';

        $this->confirmUninstall = 'Are you sure you want to uninstall?';
    }

    public function install() {
        return parent::install() && Configuration::updateValue('CWCLOUD_API_SECRET', '') && Configuration::updateValue('CWCLOUD_BCC_EMAIL', '') && $this->registerHook('actionEmailSendBefore');
    }

    public function uninstall() {
        return parent::uninstall() && Configuration::deleteByName('CWCLOUD_API_SECRET') && Configuration::deleteByName('CWCLOUD_BCC_EMAIL');
    }

    public function getContent() {
        $output = null;

        if (Tools::isSubmit('submit'.$this->name)) {
            $secret_key = strval(Tools::getValue('CWCLOUD_API_SECRET'));
            Configuration::updateValue('CWCLOUD_API_SECRET', $secret_key);

            $bcc_email = strval(Tools::getValue('CWCLOUD_BCC_EMAIL'));
            Configuration::updateValue('CWCLOUD_BCC_EMAIL', $bcc_email);

            $output .= $this->displayConfirmation($this->l('Settings updated'));
        }

        return $output.$this->displayForm();
    }

    public function displayForm() {
        $default_lang = (int)Configuration::get('PS_LANG_DEFAULT');

        $fields_form = array(
            'form' => array(
                'legend' => array(
                    'title' => $this->l('API Settings'),
                ),
                'input' => array(
                    array(
                        'type' => 'text',
                        'label' => $this->l('Secret Key'),
                        'name' => 'CWCLOUD_API_SECRET',
                        'size' => 50,
                        'required' => true
                    ),
                    array(
                        'type' => 'text',
                        'label' => $this->l('Default bcc email'),
                        'name' => 'CWCLOUD_BCC_EMAIL',
                        'size' => 100,
                        'required' => true
                    )
                ),
                'submit' => array(
                    'title' => $this->l('Save'),
                    'class' => 'btn btn-default pull-right'
                )
            ),
        );

        $helper = new HelperForm();

        $helper->module = $this;
        $helper->name_controller = $this->name;
        $helper->token = Tools::getAdminTokenLite('AdminModules');
        $helper->currentIndex = AdminController::$currentIndex.'&configure='.$this->name;

        $helper->default_form_language = $default_lang;
        $helper->allow_employee_form_lang = $default_lang;

        $helper->title = $this->displayName;
        $helper->show_toolbar = true;
        $helper->toolbar_scroll = true;
        $helper->submit_action = 'submit'.$this->name;
        $helper->toolbar_btn = array(
            'save' =>
            array(
                'desc' => $this->l('Save'),
                'href' => AdminController::$currentIndex.'&configure='.$this->name.'&save'.$this->name.
                '&token='.Tools::getAdminTokenLite('AdminModules'),
            ),
            'back' => array(
                'href' => AdminController::$currentIndex.'&token='.Tools::getAdminTokenLite('AdminModules'),
                'desc' => $this->l('Back to list')
            )
        );

        $helper->fields_value['CWCLOUD_API_SECRET'] = Configuration::get('CWCLOUD_API_SECRET');
        $helper->fields_value['CWCLOUD_BCC_EMAIL'] = Configuration::get('CWCLOUD_BCC_EMAIL');

        return $helper->generateForm(array($fields_form));
    }

    public function hookActionEmailSendBefore($params) {
        $api_endpoint = 'https://CWCLOUD_ENDPOINT_URL/v1/email';

        $from_addr = null;
        $reply_to = null;

        if (isset($params['replyTo']) && $params['replyTo']) {
            $reply_to = $params['replyTo'];
        }

        if (isset($params['from']) && $params['from']) {
           $from_addr = $params['from'];
        } else if (isset($params['email']) && $params['email']) {
            $from_addr = $params['email'];
        } else if ($reply_to) {
            $from_addr = $reply_to;
        }

        $subject = preg_replace("/\ *\[no_sync\]/", "", $params['subject']);

        $customer = "";
        if (isset($params['firstname']) && $params['firstname']) {
           $customer .= $params['firstname'];
        }
        if (isset($params['lastname']) && $params['lastname']) {
            $customer .= " " . $params['lastname'];
        }

        if ($customer) {
            $subject .= " from " . $customer;
        }

        $to_addr = $params['to'];
        
        $bcc_addr = null;
        if (isset($params['bcc']) && $params['bcc']) {
            $bcc_addr = $params['bcc'];
        } else if (Configuration::get('CWCLOUD_BCC_EMAIL')) {
            $bcc_addr = Configuration::get('CWCLOUD_BCC_EMAIL');
        }

        $cc_addr = null;
        if (isset($params['cc']) && $params['cc']) {
            $cc_addr = $params['cc'];
        }

        $data = array(
            'from' => $from_addr,
            'to' => $to_addr,
            'bcc' => $bcc_addr,
            'cc' => $cc_addr,
            'subject' => $subject,
            'replyto' => $reply_to,
            'content' => $params['message']
        );

        $json_data = json_encode($data);
        $headers = array(
            'Accept: application/json',
            'Content-Type: application/json',
            'X-Auth-Token: ' . Configuration::get('CWCLOUD_API_SECRET')
        );

        $ch = curl_init($api_endpoint);
        curl_setopt($ch, CURLOPT_POST, 1);
        curl_setopt($ch, CURLOPT_POSTFIELDS, $json_data);
        curl_setopt($ch, CURLOPT_HTTPHEADER, $headers);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        $response = curl_exec($ch);
        curl_close($ch);

        $params['send'] = false;
    }
}
