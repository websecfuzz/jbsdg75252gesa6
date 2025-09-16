<?php
/**
 * CleverReach WordPress Integration.
 *
 * @package CleverReach
 */

/**
 * Frontend controller.
 *
 * @var CleverReach\WordPress\Controllers\Clever_Reach_Frontend_Controller $this
 */
$config = $this->get_group_deleted_config();

?>
<input type="hidden" id="cr-auth-url" value="<?php echo esc_url( $config[ 'authUrl' ] ); ?>">
<input type="hidden" id="cr-check-status-url" value="<?php echo esc_url( $config[ 'checkStatusUrl' ] ); ?>">

<div class="cr-loader-big">
	<span class="cr-loader"></span>
</div>

<div class="cr-connecting">
	<span>
		<?php echo esc_html( __( 'Connecting...', 'cleverreach-wp' ) ); ?>
	</span>
</div>

<div class="cr-content-window-wrapper wpcontent">
	<div class="cr-token-expired-content-window cr-iframe">
		<div class="cr-token-expired">
			<img class="cr-welcome-icon" src="<?php echo esc_url( $config[ 'logoUrl' ] ); ?>">
			<h3>
				<?php echo esc_html( __( 'Note: Oops,', 'cleverreach-wp' ) ); ?>
			</h3>
			<div class="cr-dashboard-text-wrapper cr-main-text">
				<?php
				echo esc_html( __(
						'The sync is not working because the initial connected group is deleted in CleverReach. Please reconnect your account to use the app.',
						'cleverreach-wp'
					)
				);
				?>
			</div>
			<div class="cr-action-buttons-wrapper">
				<button class="cr-primary" id="cr-log-account">
					<?php echo esc_html( __( 'Connect now', 'cleverreach-wp' ) ); ?>
				</button>
			</div>
		</div>
		<input type="hidden" id="cr-iframe-url" value="<?php echo esc_url( $config[ 'authUrl' ] ); ?>"/>
		<iframe id="cr-iframe" class="hidden" scrolling="no">
		</iframe>
	</div>
</div>