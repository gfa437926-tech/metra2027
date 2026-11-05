import { provideHttpClient } from '@angular/common/http';
import { TestBed } from '@angular/core/testing';
import { HourlyReportsComponent } from './hourly-reports.component';

describe('HourlyReportsComponent local draft persistence', () => {
  const storageKey = 'metra.hourly-drafts.v1';

  beforeEach(() => {
    localStorage.removeItem(storageKey);
    TestBed.configureTestingModule({
      imports: [HourlyReportsComponent],
      providers: [provideHttpClient()]
    });
  });

  afterEach(() => {
    localStorage.removeItem(storageKey);
    TestBed.resetTestingModule();
  });

  it('restores valid saved drafts when the page is opened again', () => {
    localStorage.setItem(storageKey, JSON.stringify({
      format: 'metra-hourly-drafts-v1',
      savedAt: '2026-11-05T12:00:00.000Z',
      drafts: [{
        reference: 'H-0007',
        date: '2026-11-05',
        hour: '09',
        station: 'محطة اختبار',
        status: 'draft',
        values: { dryTemp: '+21.0', windSpeed: '04' }
      }]
    }));

    const fixture = TestBed.createComponent(HourlyReportsComponent);
    fixture.detectChanges();

    expect(fixture.componentInstance.previews.length).toBe(1);
    expect(fixture.componentInstance.previews[0].reference).toBe('H-0007');
    expect(fixture.componentInstance.previews[0].station).toBe('محطة اختبار');
    expect(fixture.nativeElement.textContent).toContain('H-0007');
  });

  it('ignores an unknown storage format instead of loading untrusted content', () => {
    localStorage.setItem(storageKey, JSON.stringify({
      format: 'unknown-format',
      drafts: [{
        reference: 'H-9999',
        date: '2026-11-05',
        hour: '12',
        station: 'غير موثوقة',
        status: 'draft',
        values: {}
      }]
    }));

    const fixture = TestBed.createComponent(HourlyReportsComponent);
    fixture.detectChanges();

    expect(fixture.componentInstance.previews).toEqual([]);
  });

  it('continues the reference sequence after restoring existing drafts', () => {
    localStorage.setItem(storageKey, JSON.stringify({
      format: 'metra-hourly-drafts-v1',
      drafts: [{
        reference: 'H-0042',
        date: '2026-11-05',
        hour: '12',
        station: 'محطة اختبار',
        status: 'submitted',
        values: {}
      }]
    }));

    const fixture = TestBed.createComponent(HourlyReportsComponent);
    expect((fixture.componentInstance as unknown as { nextReference: number }).nextReference)
      .toBe(43);
  });
});
