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
Object.assign(exports, require('./auth_helpers'));
Object.assign(exports, require('./early_business_access'));
Object.assign(exports, require('./event_cover'));
Object.assign(exports, require('./retention'));
Object.assign(exports, require('./spot_submission'));
