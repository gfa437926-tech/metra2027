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
    loadMore.click();
    await fixture.whenStable();
    fixture.detectChanges();

    expect(fixture.componentInstance.items().length).toBe(1);
    expect(fixture.componentInstance.loadMoreError()).toBe(true);
    expect(fixture.componentInstance.loadMoreErrorRequiresReload()).toBe(true);
    expect(fixture.nativeElement.textContent).toContain('أعد تحميل الدليل');
  });
});
