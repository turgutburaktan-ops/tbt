const {setGlobalOptions} = require('firebase-functions/v2');

// Callable functions must be reachable from the public web; application-level
// authentication and authorization remain enforced inside each handler.
setGlobalOptions({invoker: 'public'});

Object.assign(exports, require('./index'));
Object.assign(exports, require('./business'));
Object.assign(exports, require('./business_content'));
Object.assign(exports, require('./business_enhancements'));
Object.assign(exports, require('./business_growth'));
Object.assign(exports, require('./business_web_tools'));
Object.assign(exports, require('./business_maintenance'));
Object.assign(exports, require('./business_candidate'));
Object.assign(exports, require('./business_candidate_publish'));
Object.assign(exports, require('./business_claim_v2'));
Object.assign(exports, require('./business_notifications'));
Object.assign(exports, require('./admin_business_premium'));
Object.assign(exports, require('./admin_console'));
Object.assign(exports, require('./admin_broadcast_worker'));
Object.assign(exports, require('./auth_helpers'));
Object.assign(exports, require('./verification_email'));
Object.assign(exports, require('./creator_invites'));
Object.assign(exports, require('./early_business_access'));
Object.assign(exports, require('./event_cover'));
Object.assign(exports, require('./retention'));
Object.assign(exports, require('./event_reminders'));
Object.assign(exports, require('./spot_submission'));

Object.assign(exports, require('./reservation_preparation'));

const {chatAction, chatGroupMessageNotification} = require('./chat_collaboration');
Object.assign(exports, {chatAction, chatGroupMessageNotification});

const {preparePostMusic, registerOriginalPostSound, countPostSoundUse, revokeDeletedOriginalSound, removeDisabledSound} = require('./music_v1');
Object.assign(exports, {preparePostMusic, registerOriginalPostSound, countPostSoundUse, revokeDeletedOriginalSound, removeDisabledSound});
exports.approveMusicSubmission = require('./music_v1').approveMusicSubmission;
Object.assign(exports, require('./account_lifecycle'));

const {socialPublishing, creatorStudio} = require('./social_publishing');
Object.assign(exports, {socialPublishing, creatorStudio});

exports.replyToNotification=require('./notification_reply').replyToNotification;

exports.creatorAdmin = require('./creator_admin').creatorAdmin;
