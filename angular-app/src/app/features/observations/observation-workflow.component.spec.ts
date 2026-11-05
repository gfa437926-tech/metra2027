import { provideHttpClient } from '@angular/common/http';
import { provideHttpClientTesting, HttpTestingController } from '@angular/common/http/testing';
import { TestBed } from '@angular/core/testing';
import { ObservationWorkflowComponent } from './observation-workflow.component';

describe('ObservationWorkflowComponent server review queue', () => {
  let http: HttpTestingController;

  const item = {
    observationId: '10000000-0000-0000-0000-000000000001',
    stationId: '00000000-0000-0000-0000-000000000010',
    observationDate: '2026-11-05',
    utcHour: 9,
    submittedBy: '20000000-0000-0000-0000-000000000001',
    submittedAtUtc: '2026-11-05T09:00:00Z'
  };

  beforeEach(() => {
    TestBed.configureTestingModule({
      imports: [ObservationWorkflowComponent],
      providers: [provideHttpClient(), provideHttpClientTesting()]
    });
    http = TestBed.inject(HttpTestingController);
  });

  afterEach(() => {
    http.verify();
    TestBed.resetTestingModule();
  });

  it('loads the real queue and renders the station-scoped response', async () => {
    const fixture = TestBed.createComponent(ObservationWorkflowComponent);
    fixture.detectChanges();

    const request = http.expectOne(req =>
      req.method === 'GET' && req.url.endsWith('/observations/hourly/review-queue'));
    expect(request.request.withCredentials).toBeTrue();
    request.flush({ items: [item], hasMore: false, nextCursor: null });
    await fixture.whenStable();
    fixture.detectChanges();

    expect(fixture.componentInstance.items.length).toBe(1);
    expect(fixture.nativeElement.textContent).toContain(item.observationId);
    expect(fixture.nativeElement.textContent).toContain('09:00');
  });

  it('posts an approval decision and removes the resolved item from the queue', async () => {
    const fixture = TestBed.createComponent(ObservationWorkflowComponent);
    fixture.detectChanges();
    http.expectOne(req => req.method === 'GET').flush({
      items: [item], hasMore: false, nextCursor: null
    });
    await fixture.whenStable();

    const decisionPromise = fixture.componentInstance.decide(item, 1);
    const post = http.expectOne(req =>
      req.method === 'POST' && req.url.endsWith(`/observations/hourly/${item.observationId}/review`));
    expect(post.request.body).toEqual({ decision: 1, note: null });
    expect(post.request.withCredentials).toBeTrue();
    post.flush({ observationId: item.observationId, status: 'approved' });
    await decisionPromise;

    expect(fixture.componentInstance.items.length).toBe(0);
    expect(fixture.componentInstance.message).toContain('اعتماد');
  });

  it('shows a clear authentication message instead of demo data on 401', async () => {
    const fixture = TestBed.createComponent(ObservationWorkflowComponent);
    fixture.detectChanges();
    http.expectOne(req => req.method === 'GET').flush(
      { code: 'unauthenticated' },
      { status: 401, statusText: 'Unauthorized' }
    );
    await fixture.whenStable();
    fixture.detectChanges();

    expect(fixture.componentInstance.items).toEqual([]);
    expect(fixture.componentInstance.errorMessage).toContain('تسجيل الدخول');
    expect(fixture.nativeElement.textContent).not.toContain('محطة تجريبية');
  });
});
