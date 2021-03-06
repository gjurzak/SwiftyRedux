//
//  Store.swift
//  ReMVVM
//
//  Created by Dariusz Grzeszczak on 29/01/2018.
//  Copyright © 2018 Dariusz Grzeszczak. All rights reserved.
//

import Actions
import Foundation

public typealias StoreState = Any

public class Store<State: StoreState> {

    private let actionDispatcher: ActionsDispatcher
    private(set) public var state: State
    let middleware: [AnyMiddleware]

    public init(with state: State, middleware: [AnyMiddleware] = [], routingEnabled: Bool = false) {
        actionDispatcher = ActionsDispatcher(routingEnabled: routingEnabled)
        self.state = state
        self.middleware = middleware
    }

    public func register<R: Reducer>(reducer: R.Type) where State == R.State {
        actionDispatcher.register(action: reducer.Action.self) { [weak self] in
            self?.dispatch(action: $0, with: reducer)
        }
    }

    private func dispatch<Action, R: Reducer>(action: Action, with reducer: R.Type) where R.Action == Action, State == R.State {

        let reduce = { [weak self] in
            guard let strongSelf = self else { return }
            let oldState = strongSelf.state
            strongSelf.activeSubscribers.forEach { $0.willChange(state: oldState) }
            strongSelf.state = reducer.reduce(state: oldState, with: action)
            strongSelf.activeSubscribers.forEach { $0.didChange(state: strongSelf.state, oldState: oldState) }
        }

       Dispatcher<Action, State>(store: self,
                                 completion: nil,
                                 middleware: middleware,
                                 reduce: reduce,
                                 action: action)
        .next()
    }

    public func dispatch<Action: StoreAction>(action: Action) {
        actionDispatcher.dispatch(action: action)
    }

    private var subscribers = [AnyWeakStoreSubscriber<State>]()
    private var activeSubscribers: [AnyWeakStoreSubscriber<State>] {
        subscribers = subscribers.filter { $0.anyValue != nil }
        return subscribers
    }

    public func add<Subscriber>(subscriber: Subscriber) where Subscriber: StoreSubscriber, State == Subscriber.State {
        guard !activeSubscribers.contains(where: { $0.anyValue === subscriber }) else { return }
        subscribers.append(AnyWeakStoreSubscriber(subscriber: subscriber))
    }

    public func remove<Subscriber>(subscriber: Subscriber) where Subscriber: StoreSubscriber, State == Subscriber.State {
        guard let index = activeSubscribers.index(where: { $0.anyValue === subscriber }) else { return }
        subscribers.remove(at: index)
    }
}
