<?php
/**
 * The base configuration for WordPress
 *
 * The wp-config.php creation script uses this file during the installation.
 * You don't have to use the website, you can copy this file to "wp-config.php"
 * and fill in the values.
 *
 * This file contains the following configurations:
 *
 * * Database settings
 * * Secret keys
 * * Database table prefix
 * * ABSPATH
 *
 * @link https://developer.wordpress.org/advanced-administration/wordpress/wp-config/
 *
 * @package WordPress
 */

// ** Database settings - You can get this info from your web host ** //
/** The name of the database for WordPress */
define( 'DB_NAME', 'db' );

/** Database username */
define( 'DB_USER', 'root' );

/** Database password */
define( 'DB_PASSWORD', 'password' );

/** Database hostname */
define( 'DB_HOST', 'dbproxy' );

/** Database charset to use in creating database tables. */
define( 'DB_CHARSET', 'utf8mb4' );

/** The database collate type. Don't change this if in doubt. */
define( 'DB_COLLATE', '' );

/**#@+
 * Authentication unique keys and salts.
 *
 * Change these to different unique phrases! You can generate these using
 * the {@link https://api.wordpress.org/secret-key/1.1/salt/ WordPress.org secret-key service}.
 *
 * You can change these at any point in time to invalidate all existing cookies.
 * This will force all users to have to log in again.
 *
 * @since 2.6.0
 */
define( 'AUTH_KEY',         '%*Q@g96a||xX/=]r {C/a$KPJ1CiRe9ui<91N+cM[#]}x3SvclfpwW4b,X[KsFlW' );
define( 'SECURE_AUTH_KEY',  'ffxDt,OO=R4rx;Jg-_yq|eLLvX<C}uHXDT^G6|InAt7NbFAqlZ>:yMW<[.oM3enE' );
define( 'LOGGED_IN_KEY',    'EI{=}>v@=j,95RB)C:b |$!w(v53^tAro`jnJnRo@q!ps%_!2PU[0x2NlOx1u!4 ' );
define( 'NONCE_KEY',        'J5}hcNg:(?*vUKCR.pz@2|$_Q__t/3+~{GaHU*:BCh*TZe~kE.#H*Tqi<Nq(ak,8' );
define( 'AUTH_SALT',        'N~>(KpdyCGvaWJs!]$N#!{g~k94D>m7S6l.s!y_!IcOOTIbe:/M&q+a+%nPmqeHK' );
define( 'SECURE_AUTH_SALT', 'w<uU|ktJXZ}Y*yoWj=z*@G,)u596^%EX2~i&n33_rK:25iD<it;hxQSn^d7Z]-=a' );
define( 'LOGGED_IN_SALT',   '^->A:s`1Q7!h >dTRu}mPK`e`i*X%;Xpr^JPg*{+0gSK]vh_@P&(eZ1k(X-Ie]M&' );
define( 'NONCE_SALT',       '47W:lC7/>*G3P%HE,?4N/;<k%Q{q{p eCUixC6i!CaQF9~GKRpMm[H-r?&@dxq!T' );

/**#@-*/

/**
 * WordPress database table prefix.
 *
 * You can have multiple installations in one database if you give each
 * a unique prefix. Only numbers, letters, and underscores please!
 *
 * At the installation time, database tables are created with the specified prefix.
 * Changing this value after WordPress is installed will make your site think
 * it has not been installed.
 *
 * @link https://developer.wordpress.org/advanced-administration/wordpress/wp-config/#table-prefix
 */
$table_prefix = 'wp_';

/**
 * For developers: WordPress debugging mode.
 *
 * Change this to true to enable the display of notices during development.
 * It is strongly recommended that plugin and theme developers use WP_DEBUG
 * in their development environments.
 *
 * For information on other constants that can be used for debugging,
 * visit the documentation.
 *
 * @link https://developer.wordpress.org/advanced-administration/debug/debug-wordpress/
 */
define( 'WP_DEBUG', false );

/* Add any custom values between this line and the "stop editing" line. */



/* That's all, stop editing! Happy publishing. */

/** Absolute path to the WordPress directory. */
if ( ! defined( 'ABSPATH' ) ) {
	define( 'ABSPATH', __DIR__ . '/' );
}

/** Sets up WordPress vars and included files. */
require_once ABSPATH . 'wp-settings.php';
