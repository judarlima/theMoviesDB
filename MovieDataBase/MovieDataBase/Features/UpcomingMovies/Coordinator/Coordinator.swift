//
//  Coordinator.swift
//  MovieDataBase
//
//  Created by Judar Lima on 20/07/19.
//  Copyright © 2019 Judar Lima. All rights reserved.
//

import UIKit

protocol CoordinatorProtocol {
    func start()
    var navigationController: UINavigationController { get }
}

class Coordinator: CoordinatorProtocol {
    let navigationController: UINavigationController

    func start() {
        let gateway = UpcomingMoviesGateway(client: HttpClient(),
                                            adapter: UpcomingMoviesAdapter())
        let presenter = UpcomingMoviesPresenter()
        let interactor = UpcomingMoviesInteractor(gateway: gateway, presenter: presenter)
        let viewController = UpcomingMoviesViewController(interactor: interactor)
        presenter.viewController = viewController
        navigationController.pushViewController(viewController, animated: false)
    }

    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
        navigationController.navigationBar.barStyle = .blackOpaque
        navigationController.navigationBar.tintColor = #colorLiteral(red: 0.9994240403, green: 0.9855536819, blue: 0, alpha: 1)
        navigationController.navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.white]
    }
}
