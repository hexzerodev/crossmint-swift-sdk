import CrossmintService
import Http
import Utils

public enum HeadlessCheckoutOrderEndpoint {
    case getOrder(orderId: String, headers: [String: String] = [:])
    case createOrder(input: HeadlessCheckoutCreateOrderInput, headers: [String: String] = [:])
    case updateOrder(
        orderId: String, input: HeadlessCheckoutUpdateOrderInput,
        headers: [String: String] = [:])
    case processCryptoPayment(orderId: String, txId: String, headers: [String: String] = [:])
    case refreshOrder(orderId: String, headers: [String: String] = [:])

    var endpoint: Endpoint {
        let apiVersion = "2022-06-09"
        let encoder = DefaultJSONCoder()

        switch self {
        case .getOrder(let orderId, let headers):
            return Endpoint(
                path: "/\(apiVersion)/orders/\(orderId)",
                method: .get,
                headers: headers
            )
        case .createOrder(let input, let headers):
            let orderSourceHeader = OrderSourceHeader(
                sdkMetadata: OrderSourceSDKMetadata(version: SDKVersion.version)
            )
            var headersWithOrderSource = headers
            headersWithOrderSource["x-order-source"] = orderSourceHeader.json()

            return Endpoint(
                path: "/\(apiVersion)/orders",
                method: .post,
                headers: headersWithOrderSource,
                body: try? encoder.encode(input)
            )
        case .updateOrder(let orderId, let input, let headers):
            return Endpoint(
                path: "/\(apiVersion)/orders/\(orderId)",
                method: .patch,
                headers: headers,
                body: try? encoder.encode(input)
            )
        case .processCryptoPayment(let orderId, let txId, let headers):
            return Endpoint(
                path: "/\(apiVersion)/orders/\(orderId)/crypto-payment",
                method: .post,
                headers: headers,
                body: try? encoder.encode(["txId": txId])
            )
        case .refreshOrder(let orderId, let headers):
            return Endpoint(
                path: "/\(apiVersion)/orders/\(orderId)/refresh",
                method: .post,
                headers: headers
            )
        }
    }
}
