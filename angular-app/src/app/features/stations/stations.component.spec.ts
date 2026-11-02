import { TestBed } from '@angular/core/testing';
import { StationCatalogueService } from './station-catalogue.service';
import { StationsComponent } from './stations.component';

const classic = {
  sourceKind: 'classic' as const,
  sourceRecordId: 'classic-1',
  displayName: 'محطة دمشق',
  sourceStationType: null,
  sourceCode: 'D-1',
  latitude: 33.5,
  longitude: 36.3,
  elevationMetres: null
};

const automatic = {
  sourceKind: 'automatic' as const,
  sourceRecordId: 'automatic-1',
  displayName: 'محطة دمشق',
  sourceStationType: null,
  sourceCode: 'A-1',
  latitude: null,
  longitude: null,
  elevationMetres: null
};

function setup(readPage: jasmine.Spy, isConfigured = true) {
  TestBed.configureTestingModule({
    imports: [StationsComponent],
    providers: [{
      provide: StationCatalogueService,
      useValue: { isConfigured, readPage }
    }]
  });
  const fixture = TestBed.createComponent(StationsComponent);
  fixture.detectChanges();
  return fixture;
}

describe('StationsComponent', () => {
  afterEach(() => TestBed.resetTestingModule());

  it('shows the unconfigured state without requesting or fabricating records', () => {
    const readPage = jasmine.createSpy('readPage');
    const fixture = setup(readPage, false);

    expect(readPage).not.toHaveBeenCalled();
    expect(fixture.nativeElement.textContent).toContain('مصدر بيانات المحطات غير موصول بعد');
    expect(fixture.componentInstance.items().length).toBe(0);
  });

  it('keeps same-name source records separate and counts missing coordinates', async () => {
    const readPage = jasmine.createSpy('readPage').and.returnValue(Promise.resolve({
      items: [classic, automatic],
      hasMore: false,
      nextCursor: null
    }));
    const fixture = setup(readPage);
    await fixture.whenStable();
    fixture.detectChanges();

    expect(fixture.componentInstance.items().length).toBe(2);
    expect(fixture.componentInstance.classicCount()).toBe(1);
    expect(fixture.componentInstance.automaticCount()).toBe(1);
    expect(fixture.componentInstance.withoutCoordinatesCount()).toBe(1);
    expect(fixture.nativeElement.textContent).toContain('دون إحداثيات');
  });

  it('plots only complete coordinate pairs and keeps source identity visible', async () => {
    const locatedAutomatic = {
      ...automatic,
      sourceRecordId: 'automatic-located',
      displayName: 'محطة آلية ساحلية',
      latitude: 90,
      longitude: 180
    };
    const readPage = jasmine.createSpy('readPage').and.returnValue(Promise.resolve({
      items: [classic, automatic, locatedAutomatic],
      hasMore: false,
      nextCursor: null
    }));
    const fixture = setup(readPage);
    await fixture.whenStable();
    fixture.detectChanges();

    const component = fixture.componentInstance;
    expect(component.items().length).toBe(3);
    expect(component.locatedItems().length).toBe(2);
    expect(component.withoutCoordinatesCount()).toBe(1);
    expect(component.markerX(locatedAutomatic)).toBe(100);
    expect(component.markerY(locatedAutomatic)).toBe(0);
    expect(fixture.nativeElement.querySelectorAll('.plot-marker').length).toBe(2);
    expect(fixture.nativeElement.querySelectorAll('.plot-marker.classic').length).toBe(1);
    expect(fixture.nativeElement.querySelectorAll('.plot-marker.automatic').length).toBe(1);
    expect(fixture.nativeElement.textContent).toContain('محطة آلية ساحلية');
    expect(fixture.nativeElement.textContent).toContain('دون إحداثيات');
  });

  it('requests the selected source filter and exposes its pressed state', async () => {
    const readPage = jasmine.createSpy('readPage').and.returnValue(Promise.resolve({
      items: [classic],
      hasMore: false,
      nextCursor: null
    }));
    const fixture = setup(readPage);
    await fixture.whenStable();
    fixture.detectChanges();

    const buttons = Array.from(fixture.nativeElement.querySelectorAll('button')) as HTMLButtonElement[];
    const classicFilter = buttons.find(button => button.textContent?.trim() === 'الكلاسيكية');
    expect(classicFilter).toBeDefined();
    classicFilter!.click();
    await fixture.whenStable();
    fixture.detectChanges();

    expect(readPage).toHaveBeenCalledTimes(2);
    expect(readPage.calls.argsFor(1)[0]).toEqual(jasmine.objectContaining({ sourceKind: 'classic' }));
    expect(classicFilter!.getAttribute('aria-pressed')).toBe('true');
  });

  it('preserves loaded rows after a transient page failure and retries successfully', async () => {
    const readPage = jasmine.createSpy('readPage').and.returnValues(
      Promise.resolve({ items: [classic], hasMore: true, nextCursor: 'page-2' }),
      Promise.reject(new Error('Temporary network failure')),
      Promise.resolve({ items: [automatic], hasMore: false, nextCursor: null })
    );
    const fixture = setup(readPage);
    await fixture.whenStable();
    fixture.detectChanges();

    const loadMore = (Array.from(fixture.nativeElement.querySelectorAll('button')) as HTMLButtonElement[])
      .find(button => button.textContent?.includes('تحميل المزيد'));
    if (!loadMore) throw new Error('Load more button was not rendered.');
    loadMore.click();
    await fixture.whenStable();
    fixture.detectChanges();

    expect(fixture.componentInstance.items().length).toBe(1);
    expect(fixture.componentInstance.loadMoreError()).toBe(true);
    expect(fixture.componentInstance.loadMoreErrorRequiresReload()).toBe(false);

    const retry = (Array.from(fixture.nativeElement.querySelectorAll('button')) as HTMLButtonElement[])
      .find(button => button.textContent?.includes('إعادة المحاولة'));
    if (!retry) throw new Error('Retry button was not rendered.');
    retry.click();
    await fixture.whenStable();
    fixture.detectChanges();

    expect(readPage).toHaveBeenCalledTimes(3);
    expect(fixture.componentInstance.items().length).toBe(2);
    expect(fixture.componentInstance.loadMoreError()).toBe(false);
  });

  it('preserves loaded rows and requires a fresh load after a duplicate next-page identity', async () => {
    const readPage = jasmine.createSpy('readPage').and.returnValues(
      Promise.resolve({ items: [classic], hasMore: true, nextCursor: 'page-2' }),
      Promise.resolve({ items: [classic], hasMore: false, nextCursor: null })
    );
    const fixture = setup(readPage);
    await fixture.whenStable();
    fixture.detectChanges();

    const loadMore = (Array.from(fixture.nativeElement.querySelectorAll('button')) as HTMLButtonElement[])
      .find(button => button.textContent?.includes('تحميل المزيد'));
    expect(loadMore).toBeDefined();
    if (!loadMore) throw new Error('Load more button was not rendered.');
    loadMore.click();
    await fixture.whenStable();
    fixture.detectChanges();

    expect(fixture.componentInstance.items().length).toBe(1);
    expect(fixture.componentInstance.loadMoreError()).toBe(true);
    expect(fixture.componentInstance.loadMoreErrorRequiresReload()).toBe(true);
    expect(fixture.nativeElement.textContent).toContain('أعد تحميل الدليل');
  });
});
