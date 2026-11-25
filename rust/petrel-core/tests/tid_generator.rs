use petrel_core::{Tid, tid::TidGenerator};

#[test]
#[cfg(not(target_arch = "wasm32"))]
fn sequential_and_concurrent_bursts() {
    use std::collections::BTreeSet;

    let generator = TidGenerator::with_clock(7, || 1_700_000_000_000_000).unwrap();
    let mut previous = generator.next().unwrap();
    for _ in 0..400_000 {
        let next = generator.next().unwrap();
        assert!(next > previous);
        assert_eq!(next.as_str().parse::<Tid>().unwrap(), next);
        assert_eq!(next.clock_id(), 7);
        previous = next;
    }

    std::thread::scope(|scope| {
        let tasks: Vec<_> = (0..8)
            .map(|_| {
                scope.spawn(|| {
                    (0..5000)
                        .map(|_| generator.next().unwrap())
                        .collect::<Vec<_>>()
                })
            })
            .collect();
        let results: BTreeSet<_> = tasks
            .into_iter()
            .flat_map(|task| task.join().unwrap())
            .collect();
        assert_eq!(results.len(), 40_000);
        assert!(results.first().unwrap() > &previous);
    });
}

#[cfg_attr(not(target_arch = "wasm32"), test)]
#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
fn stopped_and_decreasing_clock() {
    use std::sync::{
        Arc,
        atomic::{AtomicU64, Ordering},
    };

    let time = Arc::new(AtomicU64::new(5));
    let generator = TidGenerator::with_clock(1023, {
        let time = Arc::clone(&time);
        move || time.load(Ordering::Relaxed)
    })
    .unwrap();
    for expected in 5..5005 {
        let next = generator.next().unwrap();
        assert_eq!(next.clock_id(), 1023);
        assert_eq!(next.timestamp_micros(), expected);
    }
    time.store(1, Ordering::Relaxed);
    assert_eq!(generator.next().unwrap().timestamp_micros(), 5005);

    let boundary = TidGenerator::with_clock(0, || Tid::MAX_TIMESTAMP_MICROS).unwrap();
    assert_eq!(
        boundary.next().unwrap().timestamp_micros(),
        Tid::MAX_TIMESTAMP_MICROS
    );
    assert!(boundary.next().is_err());
    assert!(TidGenerator::with_clock(1024, || 0).is_err());
}

#[cfg_attr(not(target_arch = "wasm32"), test)]
#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
fn previous_revision() {
    let generator = TidGenerator::with_clock(3, || 100).unwrap();
    let prior = Tid::from_parts(99, 1023).unwrap();
    assert_eq!(
        generator.next_after(&prior).unwrap().timestamp_micros(),
        100
    );
    let future = Tid::from_parts(1000, 1023).unwrap();
    let after_future = generator.next_after(&future).unwrap();
    assert_eq!(after_future.timestamp_micros(), 1001);
    // Chaining advances cleanly past `after_future`, while `next()` is NOT
    // dragged into the far future by an external peer's skewed timestamp.
    assert_eq!(
        generator
            .next_after(&after_future)
            .unwrap()
            .timestamp_micros(),
        1002
    );
    let local = generator.next().unwrap();
    assert_eq!(local.timestamp_micros(), 103);
    assert!(local > prior);

    let near_max = Tid::from_parts(Tid::MAX_TIMESTAMP_MICROS - 1, 0).unwrap();
    assert_eq!(
        generator.next_after(&near_max).unwrap().timestamp_micros(),
        Tid::MAX_TIMESTAMP_MICROS
    );
    assert!(generator.next().unwrap().timestamp_micros() < 1000);
    for first in "234567ab".chars() {
        let tid = Tid::parse(format!("{first}222222222222")).unwrap();
        assert!(generator.next_after(&tid).unwrap() > tid);
    }
    for first in "cdefghij".chars() {
        let tid = Tid::parse(format!("{first}222222222222")).unwrap();
        assert!(generator.next_after(&tid).is_err());
    }
    let max = Tid::from_parts(Tid::MAX_TIMESTAMP_MICROS, 0).unwrap();
    assert!(generator.next_after(&max).is_err());
}

#[cfg(any(not(target_arch = "wasm32"), feature = "wasm"))]
#[cfg_attr(not(target_arch = "wasm32"), test)]
#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
fn system_clock_and_rng() {
    let generator = TidGenerator::shared().unwrap();
    let first = generator.next().unwrap();
    let second = generator.next().unwrap();
    assert!(first < second);
    assert_eq!(first.clock_id(), second.clock_id());
    assert!(first.timestamp_micros() > 1_700_000_000_000_000);
    assert!(petrel_core::Datetime::now().unwrap().unix_seconds() > 1_700_000_000);
}
