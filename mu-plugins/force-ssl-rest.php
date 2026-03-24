<?php
/**
 * Force is_ssl() to return true for WooCommerce REST API requests.
 * This allows query-string and basic authentication over HTTP in local development.
 * DO NOT USE IN PRODUCTION.
 */
add_filter("pre_option_woocommerce_force_ssl_checkout", function() { return "no"; });
add_filter("determine_current_user", function($user_id) {
    if (!empty($_SERVER["REQUEST_URI"]) && strpos($_SERVER["REQUEST_URI"], "/wp-json/wc/") !== false) {
        $_SERVER["HTTPS"] = "on";
    }
    return $user_id;
}, 5);
