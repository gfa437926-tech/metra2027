import { getTestBed } from '@angular/core/testing';
import { BrowserTestingModule, platformBrowserTesting } from '@angular/platform-browser/testing';

getTestBed().initTestEnvironment(
  [BrowserTestingModule],
  platformBrowserTesting(),
  {
    errorOnUnknownElements: true,
    errorOnUnknownProperties: true
  }
);

import './app/features/stations/station-catalogue.service.spec';
import './app/features/stations/stations.component.spec';
