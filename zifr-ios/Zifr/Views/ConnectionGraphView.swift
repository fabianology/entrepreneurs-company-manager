import SwiftUI

enum ConnectionGraphNodeKind: Hashable {
    case resource(ResourceKind)
    case sharedEmail
}

struct ConnectionGraphNode: Identifiable, Hashable {
    let id: String
    let kind: ConnectionGraphNodeKind
    let reference: ResourceReference?
    let displayName: String
    let canvasLabel: String
    var degree: Int = 0
    var radius: CGFloat = 18
}

struct ConnectionGraphEdge: Identifiable, Hashable {
    let id: String
    let sourceID: String
    let targetID: String
    let relationship: ConnectionRelationship
    let state: ConnectionState
    let connectionIDs: [UUID]

    func otherNodeID(from nodeID: String) -> String? {
        if sourceID == nodeID { return targetID }
        if targetID == nodeID { return sourceID }
        return nil
    }
}

struct ConnectionGraph: Hashable {
    var nodes: [ConnectionGraphNode]
    var edges: [ConnectionGraphEdge]

    static let empty = ConnectionGraph(nodes: [], edges: [])

    var layoutKey: String {
        nodes.map(\.id).sorted().joined(separator: "|")
    }

    func node(id: String) -> ConnectionGraphNode? {
        nodes.first { $0.id == id }
    }

    func edges(for nodeID: String) -> [ConnectionGraphEdge] {
        edges.filter { $0.sourceID == nodeID || $0.targetID == nodeID }
    }

    func neighborIDs(for nodeID: String) -> Set<String> {
        Set(edges(for: nodeID).compactMap { $0.otherNodeID(from: nodeID) })
    }
}

enum ConnectionGraphBuilder {
    static func build(appState: AppState) -> ConnectionGraph {
        var nodes: [String: ConnectionGraphNode] = [:]
        var edges: [String: ConnectionGraphEdge] = [:]

        func nodeID(_ reference: ResourceReference) -> String { "resource:\(reference.id)" }

        func addNode(_ reference: ResourceReference, name: String? = nil) {
            let id = nodeID(reference)
            guard nodes[id] == nil else { return }
            let fullName = name ?? PortfolioConnectionEngine.displayName(for: reference, appState: appState)
            nodes[id] = ConnectionGraphNode(
                id: id,
                kind: .resource(reference.kind),
                reference: reference,
                displayName: fullName,
                canvasLabel: maskedCanvasLabel(for: reference.kind, name: fullName)
            )
        }

        func edgeKey(_ sourceID: String, _ targetID: String, _ relationship: ConnectionRelationship) -> String {
            let pair = [sourceID, targetID].sorted().joined(separator: "|")
            return "\(pair)|\(relationship.rawValue)"
        }

        for company in appState.companies {
            addNode(ResourceReference(kind: .company, resourceId: company.id), name: company.name)
        }
        for subscription in appState.subscriptions {
            addNode(ResourceReference(kind: .subscription, resourceId: subscription.id), name: subscription.name)
        }
        for institution in appState.institutions {
            addNode(ResourceReference(kind: .institution, resourceId: institution.id), name: institution.name)
        }
        for card in appState.cards {
            let suffix = (card.last4 ?? "").isEmpty ? "" : " •••• \(card.last4 ?? "")"
            addNode(ResourceReference(kind: .card, resourceId: card.id), name: card.name + suffix)
        }
        for loan in appState.loans {
            addNode(ResourceReference(kind: .loan, resourceId: loan.id), name: loan.name)
        }
        for document in appState.documents {
            addNode(ResourceReference(kind: .document, resourceId: document.id), name: document.name)
        }

        let activeConnections = appState.resourceConnections.filter { $0.state != .rejected }
        let emailConnections = Dictionary(grouping: activeConnections.compactMap { connection -> (String, ResourceConnection)? in
            guard connection.relationshipType == .usesLogin,
                  let key = connection.inferenceKey,
                  let email = emailFromInferenceKey(key) else { return nil }
            return (email, connection)
        }, by: \.0)

        let emailConnectionIDs = Set(emailConnections.values.flatMap { $0.map { $0.1.id } })

        for connection in activeConnections where !emailConnectionIDs.contains(connection.id) {
            addNode(connection.source)
            addNode(connection.target)
            let sourceID = nodeID(connection.source)
            let targetID = nodeID(connection.target)
            let key = edgeKey(sourceID, targetID, connection.relationshipType)
            if let existing = edges[key] {
                edges[key] = ConnectionGraphEdge(
                    id: existing.id,
                    sourceID: existing.sourceID,
                    targetID: existing.targetID,
                    relationship: existing.relationship,
                    state: mergedState(existing.state, connection.state),
                    connectionIDs: Array(Set(existing.connectionIDs + [connection.id])).sorted { $0.uuidString < $1.uuidString }
                )
            } else {
                edges[key] = ConnectionGraphEdge(
                    id: key,
                    sourceID: sourceID,
                    targetID: targetID,
                    relationship: connection.relationshipType,
                    state: connection.state,
                    connectionIDs: [connection.id]
                )
            }
        }

        for (email, groupedValues) in emailConnections {
            let connections = groupedValues.map(\.1)
            let references = Set(connections.flatMap { [$0.source, $0.target] })
            guard references.count > 1 else { continue }
            let emailNodeID = "email:\(email)"
            nodes[emailNodeID] = ConnectionGraphNode(
                id: emailNodeID,
                kind: .sharedEmail,
                reference: nil,
                displayName: email,
                canvasLabel: maskEmail(email)
            )
            for reference in references {
                addNode(reference)
                let related = connections.filter { $0.source == reference || $0.target == reference }
                let state: ConnectionState = related.contains { $0.state == .suggested } ? .suggested : .confirmed
                let resourceNodeID = nodeID(reference)
                let key = edgeKey(emailNodeID, resourceNodeID, .usesLogin)
                edges[key] = ConnectionGraphEdge(
                    id: key,
                    sourceID: resourceNodeID,
                    targetID: emailNodeID,
                    relationship: .usesLogin,
                    state: state,
                    connectionIDs: related.map(\.id).sorted { $0.uuidString < $1.uuidString }
                )
            }
        }

        addOwnershipEdges(appState: appState, nodes: &nodes, edges: &edges)

        let neighbors = edges.values.reduce(into: [String: Set<String>]()) { result, edge in
            result[edge.sourceID, default: []].insert(edge.targetID)
            result[edge.targetID, default: []].insert(edge.sourceID)
        }
        for id in nodes.keys {
            let degree = neighbors[id]?.count ?? 0
            guard var node = nodes[id] else { continue }
            node.degree = degree
            node.radius = radius(kind: node.kind, degree: degree)
            nodes[id] = node
        }

        return ConnectionGraph(
            nodes: nodes.values.sorted { lhs, rhs in
                if lhs.degree != rhs.degree { return lhs.degree > rhs.degree }
                return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            },
            edges: edges.values.sorted { $0.id < $1.id }
        )
    }

    static func radius(kind: ConnectionGraphNodeKind, degree: Int) -> CGFloat {
        let influence = sqrt(CGFloat(max(0, degree)))
        switch kind {
        case .resource(.company): return min(52, 28 + influence * 7)
        case .sharedEmail: return min(42, 20 + influence * 6)
        default: return min(38, 18 + influence * 6)
        }
    }

    private static func addOwnershipEdges(
        appState: AppState,
        nodes: inout [String: ConnectionGraphNode],
        edges: inout [String: ConnectionGraphEdge]
    ) {
        func connect(kind: ResourceKind, resourceID: UUID, companyID: UUID, relationship: ConnectionRelationship = .belongsTo) {
            let resourceNodeID = "resource:\(kind.rawValue):\(resourceID.uuidString)"
            let companyNodeID = "resource:\(ResourceKind.company.rawValue):\(companyID.uuidString)"
            guard nodes[resourceNodeID] != nil, nodes[companyNodeID] != nil else { return }
            let pair = [resourceNodeID, companyNodeID].sorted().joined(separator: "|")
            let key = "\(pair)|\(relationship.rawValue)"
            guard edges[key] == nil else { return }
            edges[key] = ConnectionGraphEdge(
                id: key,
                sourceID: resourceNodeID,
                targetID: companyNodeID,
                relationship: relationship,
                state: .confirmed,
                connectionIDs: []
            )
        }

        appState.subscriptions.forEach { connect(kind: .subscription, resourceID: $0.id, companyID: $0.companyId) }
        appState.institutions.forEach { connect(kind: .institution, resourceID: $0.id, companyID: $0.companyId) }
        appState.cards.forEach { connect(kind: .card, resourceID: $0.id, companyID: $0.companyId) }
        appState.loans.forEach { connect(kind: .loan, resourceID: $0.id, companyID: $0.companyId) }
        appState.documents.forEach { connect(kind: .document, resourceID: $0.id, companyID: $0.companyId, relationship: .documentFor) }
    }

    private static func emailFromInferenceKey(_ key: String) -> String? {
        guard key.hasPrefix("email:") else { return nil }
        let email = String(key.dropFirst("email:".count).split(separator: ":", maxSplits: 1).first ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return email.contains("@") ? email : nil
    }

    private static func mergedState(_ lhs: ConnectionState, _ rhs: ConnectionState) -> ConnectionState {
        lhs == .confirmed || rhs == .confirmed ? .confirmed : .suggested
    }

    private static func maskedCanvasLabel(for kind: ResourceKind, name: String) -> String {
        if kind == .card, let range = name.range(of: "••••") {
            return String(name[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
        }
        return name
    }

    private static func maskEmail(_ email: String) -> String {
        let pieces = email.split(separator: "@", maxSplits: 1).map(String.init)
        guard pieces.count == 2 else { return "Shared email" }
        let first = pieces[0].prefix(1)
        return "\(first)•••@\(pieces[1])"
    }
}

enum ConnectionGraphLayoutEngine {
    static func positions(for graph: ConnectionGraph, iterations: Int = 150) -> [String: CGPoint] {
        guard !graph.nodes.isEmpty else { return [:] }
        if graph.nodes.count == 1 { return [graph.nodes[0].id: .zero] }

        var positions: [String: CGPoint] = [:]
        var velocities: [String: CGVector] = [:]
        let count = CGFloat(graph.nodes.count)

        for (index, node) in graph.nodes.enumerated() {
            let seed = stableSeed(node.id)
            let angle = (CGFloat(index) / count) * .pi * 2 + CGFloat(seed % 97) / 97 * 0.35
            let ring = 0.20 + CGFloat(seed % 23) / 23 * 0.18
            positions[node.id] = CGPoint(x: cos(angle) * ring, y: sin(angle) * ring)
            velocities[node.id] = .zero
        }

        let edgePairs = graph.edges.map { ($0.sourceID, $0.targetID) }
        for step in 0..<max(1, iterations) {
            var forces = Dictionary(uniqueKeysWithValues: graph.nodes.map { ($0.id, CGVector.zero) })

            for leftIndex in graph.nodes.indices {
                for rightIndex in graph.nodes.indices where rightIndex > leftIndex {
                    let leftID = graph.nodes[leftIndex].id
                    let rightID = graph.nodes[rightIndex].id
                    guard let left = positions[leftID], let right = positions[rightID] else { continue }
                    var dx = left.x - right.x
                    var dy = left.y - right.y
                    let distanceSquared = max(0.0006, dx * dx + dy * dy)
                    let distance = sqrt(distanceSquared)
                    dx /= distance
                    dy /= distance
                    let strength = min(0.012, 0.0018 / distanceSquared)
                    forces[leftID]?.dx += dx * strength
                    forces[leftID]?.dy += dy * strength
                    forces[rightID]?.dx -= dx * strength
                    forces[rightID]?.dy -= dy * strength
                }
            }

            for (sourceID, targetID) in edgePairs {
                guard let source = positions[sourceID], let target = positions[targetID] else { continue }
                let dx = target.x - source.x
                let dy = target.y - source.y
                let distance = max(0.001, sqrt(dx * dx + dy * dy))
                let stretch = distance - 0.16
                let force = stretch * 0.018
                forces[sourceID]?.dx += (dx / distance) * force
                forces[sourceID]?.dy += (dy / distance) * force
                forces[targetID]?.dx -= (dx / distance) * force
                forces[targetID]?.dy -= (dy / distance) * force
            }

            let cooling = 1 - CGFloat(step) / CGFloat(max(1, iterations)) * 0.62
            for node in graph.nodes {
                guard var point = positions[node.id], var velocity = velocities[node.id] else { continue }
                let force = forces[node.id] ?? .zero
                velocity.dx = (velocity.dx + force.dx - point.x * 0.0025) * 0.82 * cooling
                velocity.dy = (velocity.dy + force.dy - point.y * 0.0025) * 0.82 * cooling
                velocity.dx = min(0.025, max(-0.025, velocity.dx))
                velocity.dy = min(0.025, max(-0.025, velocity.dy))
                point.x += velocity.dx
                point.y += velocity.dy
                positions[node.id] = point
                velocities[node.id] = velocity
            }
        }

        let xs = positions.values.map(\.x)
        let ys = positions.values.map(\.y)
        guard let minX = xs.min(), let maxX = xs.max(), let minY = ys.min(), let maxY = ys.max() else { return positions }
        let width = max(0.01, maxX - minX)
        let height = max(0.01, maxY - minY)
        let span = max(width, height)
        return positions.mapValues { point in
            CGPoint(x: (point.x - (minX + maxX) / 2) / span, y: (point.y - (minY + maxY) / 2) / span)
        }
    }

    private static func stableSeed(_ value: String) -> Int {
        value.unicodeScalars.reduce(17) { (($0 &* 31) &+ Int($1.value)) & 0x7fffffff }
    }
}

struct ConnectionGraphView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    let onOpenResource: (ResourceReference) -> Void

    @State private var positions: [String: CGPoint] = [:]
    @State private var selectedNodeID: String?
    @State private var zoom: CGFloat = 1
    @State private var zoomStart: CGFloat?
    @State private var panOffset: CGSize = .zero
    @State private var panStart: CGSize?
    @State private var draggedNodeID: String?
    @State private var dragWasNode = false

    private var graph: ConnectionGraph { ConnectionGraphBuilder.build(appState: appState) }
    private var selectedNode: ConnectionGraphNode? { selectedNodeID.flatMap(graph.node(id:)) }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.zifrBG.ignoresSafeArea()

                if graph.nodes.isEmpty {
                    ContentUnavailableView(
                        "No Connections Yet",
                        systemImage: "point.3.connected.trianglepath.dotted",
                        description: Text("Add resources or confirm suggested relationships to build your portfolio map.")
                    )
                    .foregroundStyle(.white)
                } else {
                    GeometryReader { geometry in
                        graphCanvas(size: geometry.size)
                    }
                    .ignoresSafeArea(edges: .bottom)

                    VStack(spacing: 0) {
                        graphLegend
                            .padding(.horizontal, 14)
                            .padding(.top, 8)
                        Spacer()
                        if let selectedNode {
                            ConnectionGraphInspector(
                                node: selectedNode,
                                graph: graph,
                                onOpen: open,
                                onSetState: setState
                            )
                            .padding(.horizontal, 12)
                            .padding(.bottom, 8)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                }
            }
            .navigationTitle("Connections")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.zifrGold)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            zoom = 1
                            panOffset = .zero
                            selectedNodeID = nil
                        }
                    } label: {
                        Image(systemName: "viewfinder")
                    }
                    .foregroundStyle(Color.zifrGold)
                    .accessibilityLabel("Fit graph")
                }
            }
            .task(id: graph.layoutKey) {
                positions = ConnectionGraphLayoutEngine.positions(for: graph)
                selectedNodeID = selectedNodeID.flatMap { graph.node(id: $0) == nil ? nil : $0 }
            }
            .animation(.easeInOut(duration: 0.18), value: selectedNodeID)
        }
    }

    private func graphCanvas(size: CGSize) -> some View {
        let base = max(240, min(size.width, size.height) * 0.82)
        let neighborIDs = selectedNodeID.map(graph.neighborIDs(for:)) ?? []

        return Canvas { context, _ in
            for edge in graph.edges {
                guard let source = positions[edge.sourceID], let target = positions[edge.targetID] else { continue }
                let start = screenPoint(source, size: size, base: base)
                let end = screenPoint(target, size: size, base: base)
                var path = Path()
                path.move(to: start)
                path.addLine(to: end)
                let isRelated = selectedNodeID == nil || edge.sourceID == selectedNodeID || edge.targetID == selectedNodeID
                let color = edge.state == .suggested ? Color.zifrGold : Color.white
                context.stroke(
                    path,
                    with: .color(color.opacity(isRelated ? (edge.state == .suggested ? 0.54 : 0.24) : 0.055)),
                    style: StrokeStyle(lineWidth: isRelated ? 1.25 : 0.7, dash: edge.state == .suggested ? [5, 5] : [])
                )
            }

            let orderedNodes = graph.nodes.sorted { $0.id == selectedNodeID ? false : $1.id == selectedNodeID }
            for node in orderedNodes {
                guard let position = positions[node.id] else { continue }
                let point = screenPoint(position, size: size, base: base)
                let isSelected = node.id == selectedNodeID
                let isRelated = selectedNodeID == nil || isSelected || neighborIDs.contains(node.id)
                let radius = node.radius * min(1.45, sqrt(zoom))

                if isSelected {
                    let halo = Path(ellipseIn: CGRect(x: point.x - radius - 7, y: point.y - radius - 7, width: (radius + 7) * 2, height: (radius + 7) * 2))
                    context.fill(halo, with: .color(Color.zifrGold.opacity(0.2)))
                }

                let circle = Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2))
                context.fill(circle, with: .color(nodeColor(node.kind).opacity(isRelated ? 0.92 : 0.2)))
                context.stroke(circle, with: .color((isSelected ? Color.zifrGold : Color.white).opacity(isRelated ? 0.55 : 0.12)), lineWidth: isSelected ? 2 : 0.8)

                let icon = Text(Image(systemName: nodeIcon(node.kind)))
                    .font(.system(size: min(19, radius * 0.62), weight: .bold))
                    .foregroundColor(.white.opacity(isRelated ? 0.96 : 0.28))
                context.draw(icon, at: point, anchor: .center)

                if shouldShowLabel(node: node, isSelected: isSelected) {
                    let label = Text(shortLabel(node.canvasLabel))
                        .font(.system(size: isSelected ? 11 : 9, weight: .semibold))
                        .foregroundColor(.white.opacity(isRelated ? 0.88 : 0.22))
                    context.draw(label, at: CGPoint(x: point.x, y: point.y + radius + 10), anchor: .center)
                }
            }
        }
        .contentShape(Rectangle())
        .gesture(dragGesture(size: size, base: base))
        .simultaneousGesture(magnificationGesture)
        .simultaneousGesture(
            SpatialTapGesture().onEnded { value in
                selectedNodeID = nearestNode(to: value.location, size: size, base: base)
            }
        )
        .accessibilityRepresentation {
            ScrollView {
                VStack {
                    ForEach(graph.nodes) { node in
                        Button {
                            selectedNodeID = node.id
                        } label: {
                            Text("\(node.displayName), \(node.degree) connection\(node.degree == 1 ? "" : "s")")
                        }
                    }
                }
            }
        }
    }

    private func dragGesture(size: CGSize, base: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .local)
            .onChanged { value in
                if panStart == nil && draggedNodeID == nil {
                    draggedNodeID = nearestNode(to: value.startLocation, size: size, base: base)
                    dragWasNode = draggedNodeID != nil
                    if draggedNodeID == nil { panStart = panOffset }
                }
                if let draggedNodeID {
                    positions[draggedNodeID] = graphPoint(value.location, size: size, base: base)
                    selectedNodeID = draggedNodeID
                } else if let panStart {
                    panOffset = CGSize(width: panStart.width + value.translation.width, height: panStart.height + value.translation.height)
                }
            }
            .onEnded { _ in
                if dragWasNode { UISelectionFeedbackGenerator().selectionChanged() }
                panStart = nil
                draggedNodeID = nil
                dragWasNode = false
            }
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                if zoomStart == nil { zoomStart = zoom }
                zoom = min(4, max(0.65, (zoomStart ?? zoom) * value))
            }
            .onEnded { _ in zoomStart = nil }
    }

    private var graphLegend: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                legendItem(.resource(.company), "Entity")
                legendItem(.resource(.institution), "Bank")
                legendItem(.resource(.subscription), "Subscription")
                legendItem(.resource(.card), "Card")
                legendItem(.resource(.loan), "Loan")
                legendItem(.resource(.document), "Document")
                legendItem(.resource(.collaborator), "Collaborator")
                legendItem(.sharedEmail, "Shared email")
                HStack(spacing: 5) {
                    Capsule().fill(Color.zifrGold.opacity(0.75)).frame(width: 18, height: 1)
                    Text("Suggested").font(.system(size: 9, weight: .semibold)).foregroundStyle(Color.white.opacity(0.48))
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 34)
        }
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 0.7))
    }

    private func legendItem(_ kind: ConnectionGraphNodeKind, _ title: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(nodeColor(kind)).frame(width: 7, height: 7)
            Text(title).font(.system(size: 9, weight: .semibold)).foregroundStyle(Color.white.opacity(0.54))
        }
    }

    private func screenPoint(_ point: CGPoint, size: CGSize, base: CGFloat) -> CGPoint {
        CGPoint(
            x: size.width / 2 + panOffset.width + point.x * base * zoom,
            y: size.height / 2 + panOffset.height + point.y * base * zoom
        )
    }

    private func graphPoint(_ point: CGPoint, size: CGSize, base: CGFloat) -> CGPoint {
        CGPoint(
            x: (point.x - size.width / 2 - panOffset.width) / (base * zoom),
            y: (point.y - size.height / 2 - panOffset.height) / (base * zoom)
        )
    }

    private func nearestNode(to point: CGPoint, size: CGSize, base: CGFloat) -> String? {
        graph.nodes.compactMap { node -> (String, CGFloat)? in
            guard let position = positions[node.id] else { return nil }
            let screen = screenPoint(position, size: size, base: base)
            let distance = hypot(screen.x - point.x, screen.y - point.y)
            let hitRadius = max(28, node.radius * min(1.45, sqrt(zoom)) + 8)
            return distance <= hitRadius ? (node.id, distance) : nil
        }.min { $0.1 < $1.1 }?.0
    }

    private func shouldShowLabel(node: ConnectionGraphNode, isSelected: Bool) -> Bool {
        if isSelected || zoom > 1.35 { return true }
        if case .resource(.company) = node.kind { return true }
        return node.degree >= 3
    }

    private func shortLabel(_ value: String) -> String {
        value.count > 18 ? String(value.prefix(17)) + "…" : value
    }

    private func open(_ reference: ResourceReference) {
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            onOpenResource(reference)
        }
    }

    private func setState(_ edge: ConnectionGraphEdge, _ state: ConnectionState) {
        let previous = appState.resourceConnections.filter { edge.connectionIDs.contains($0.id) }
        guard !previous.isEmpty else { return }
        for connection in previous {
            guard let index = appState.resourceConnections.firstIndex(where: { $0.id == connection.id }) else { continue }
            appState.resourceConnections[index].state = state
            appState.resourceConnections[index].updatedAt = Date()
        }
        Task {
            do {
                for connection in previous {
                    guard let updated = appState.resourceConnections.first(where: { $0.id == connection.id }) else { continue }
                    try await DataRepository.shared.updateConnection(updated)
                }
            } catch {
                for connection in previous {
                    if let index = appState.resourceConnections.firstIndex(where: { $0.id == connection.id }) {
                        appState.resourceConnections[index] = connection
                    }
                }
                appState.error = "Could not update this connection."
            }
        }
    }
}

private struct ConnectionGraphInspector: View {
    let node: ConnectionGraphNode
    let graph: ConnectionGraph
    let onOpen: (ResourceReference) -> Void
    let onSetState: (ConnectionGraphEdge, ConnectionState) -> Void

    private var edges: [ConnectionGraphEdge] {
        graph.edges(for: node.id).sorted {
            if $0.state != $1.state { return $0.state == .suggested }
            return $0.relationship.label < $1.relationship.label
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 11) {
                Image(systemName: nodeIcon(node.kind))
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(nodeColor(node.kind), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(node.displayName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    Text("\(nodeKindTitle(node.kind)) • \(node.degree) connection\(node.degree == 1 ? "" : "s")")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.42))
                }
                Spacer()
                if let reference = node.reference, reference.kind != .collaborator {
                    Button("Open") { onOpen(reference) }
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.zifrBG)
                        .padding(.horizontal, 13)
                        .frame(height: 34)
                        .background(Color.zifrGold, in: Capsule())
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(edges) { edge in
                        let other = edge.otherNodeID(from: node.id).flatMap(graph.node(id:))
                        VStack(alignment: .leading, spacing: 5) {
                            Text(edge.relationship.label.uppercased())
                                .font(.system(size: 7, weight: .black))
                                .tracking(0.6)
                                .foregroundStyle(edge.state == .suggested ? Color.zifrGold : Color.white.opacity(0.34))
                            Text(other?.canvasLabel ?? "Connection")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            if edge.state == .suggested && !edge.connectionIDs.isEmpty {
                                HStack(spacing: 10) {
                                    Button("Reject") { onSetState(edge, .rejected) }
                                        .foregroundStyle(Color.white.opacity(0.5))
                                    Button("Confirm") { onSetState(edge, .confirmed) }
                                        .foregroundStyle(.green)
                                }
                                .font(.system(size: 9, weight: .bold))
                            }
                        }
                        .padding(10)
                        .frame(width: 145, height: edge.state == .suggested ? 74 : 58, alignment: .leading)
                        .background(Color.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 0.7))
                    }
                }
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.white.opacity(0.14), lineWidth: 0.8))
    }
}

private func nodeIcon(_ kind: ConnectionGraphNodeKind) -> String {
    switch kind {
    case .resource(.company): return "building.2.fill"
    case .resource(.subscription): return "arrow.triangle.2.circlepath"
    case .resource(.institution): return "building.columns.fill"
    case .resource(.card): return "creditcard.fill"
    case .resource(.loan): return "banknote.fill"
    case .resource(.document): return "doc.fill"
    case .resource(.collaborator): return "person.fill"
    case .sharedEmail: return "envelope.fill"
    }
}

private func nodeColor(_ kind: ConnectionGraphNodeKind) -> Color {
    switch kind {
    case .resource(.company): return Color(hex: "#918457")
    case .resource(.subscription): return Color(hex: "#7C6FE8")
    case .resource(.institution): return Color(hex: "#3B82F6")
    case .resource(.card): return Color(hex: "#14B8A6")
    case .resource(.loan): return Color(hex: "#F59E0B")
    case .resource(.document): return Color(hex: "#64748B")
    case .resource(.collaborator): return Color(hex: "#EC4899")
    case .sharedEmail: return Color(hex: "#8B5CF6")
    }
}

private func nodeKindTitle(_ kind: ConnectionGraphNodeKind) -> String {
    switch kind {
    case .resource(let resource): return resource.rawValue.capitalized
    case .sharedEmail: return "Shared email"
    }
}
