
import Market from './components/Market'
import Trade from './components/Trade'
import Error from './components/Error'
import Test from './components/Test'
import Train from './components/Train'

import TraderAppBar from './components/TraderAppBar'

import './App.css';
import { v4 as uuidv4 } from 'uuid';
import { Route, NavLink, HashRouter, BrowserRouter, Routes } from "react-router-dom";

import { initSDK } from '@embrace-io/web-sdk';
import { user } from '@embrace-io/web-sdk';
import { log } from '@embrace-io/web-sdk';
import { createReactRouterNavigationInstrumentation } from '@embrace-io/web-sdk/react-instrumentation';
import { withEmbraceRouting } from '@embrace-io/web-sdk/react-instrumentation';

initSDK({
  appID: '$EMBRACE_APP_ID',
  defaultInstrumentationConfig: {
    '@opentelemetry/instrumentation-fetch': {
      propagateTraceHeaderCorsUrls: [
        new RegExp('/.*/')
      ],
    },
    '@opentelemetry/instrumentation-xml-http-request': {
      propagateTraceHeaderCorsUrls: [
        new RegExp('/.*/')
      ],
    },
  },
  dynamicSDKConfig: {
    networkSpansForwardingThreshold: 100,
  },
});

var userId=uuidv4();
user.setUserId(`${userId}@example.com`);

log.message('Loading app...', 'info');

const EmbraceRoutes = withEmbraceRouting(Routes);

function App() {
  return (
    <BrowserRouter>
      <div className="App">
        <TraderAppBar />
        <div className="content">
          <EmbraceRoutes>
            <Route exact path="/" element={<Trade />} />
            <Route path="/market" element={<Market />} />
            <Route path="/error" element={<Error />} />
            <Route path="/test" element={<Test />} />
            <Route path="/train" element={<Train />} />
          </EmbraceRoutes>
        </div>
      </div>
    </BrowserRouter>
  );
}

export default App;